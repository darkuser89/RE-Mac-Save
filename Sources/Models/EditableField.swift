import Foundation

struct EditableField:Identifiable {
    let id:Int
    let title:String
    let description:String
    let scalar:SaveScalar
    let maximum:UInt64
    let factor:UInt64
    let mirrors:[SaveScalar]
    let minimum:UInt64
    init(id:Int,title:String,description:String,scalar:SaveScalar,maximum:UInt64,factor:UInt64,mirrors:[SaveScalar]=[],minimum:UInt64=0) {
        self.id=id;self.title=title;self.description=description;self.scalar=scalar;self.maximum=maximum;self.factor=factor;self.mirrors=mirrors;self.minimum=minimum
    }
    var isFloating:Bool {scalar.type==11 || scalar.type==12}
    var initial:String {
        if scalar.type==2 {return scalar.text=="true" ? "1":"0"}
        if scalar.type==11,let number=Float(scalar.text) {return display(UInt64(number.bitPattern))}
        if scalar.type==12,let number=Double(scalar.text) {return display(number.bitPattern)}
        guard let raw=UInt64(scalar.text) else {return scalar.text}
        return display(raw)
    }
    func display(_ raw:UInt64) -> String {
        if scalar.type==11 {return String(Double(Float(bitPattern:UInt32(raw)))/Double(factor))}
        if scalar.type==12 {return String(Double(bitPattern:raw)/Double(factor))}
        let whole=raw/factor,remainder=raw%factor
        guard remainder != 0 else {return String(whole)}
        let digits=String(factor).count-1
        var fraction=String(repeating:"0",count:max(0,digits-String(remainder).count))+String(remainder)
        while fraction.last=="0" {fraction.removeLast()}
        return "\(whole).\(fraction)"
    }
    func rawValue(_ input:String) throws -> UInt64 {
        let text=input.trimmingCharacters(in:.whitespacesAndNewlines).replacingOccurrences(of:",",with:".")
        if scalar.type==2 {
            guard text=="0" || text=="1" else {throw SaveError.invalid("\(title): Nur gefunden oder nicht gefunden ist zulässig.")}
            return text=="1" ? 1:0
        }
        func invalid() -> SaveError {SaveError.invalid("\(title): Bitte einen Wert zwischen \(minimum) und \(maximum)\(factor>1 || isFloating ? " (Dezimalstellen erlaubt)" : " als ganze Zahl") eingeben.")}
        if isFloating {
            guard let number=Double(text),number.isFinite,number>=0,number<=Double(maximum) else {throw invalid()}
            if scalar.type==11 {
                let value=Float(number*Double(factor))
                guard value.isFinite,Double(value)<=Double(maximum)*Double(factor) else {throw invalid()}
                return UInt64(value.bitPattern)
            }
            if text==initial,let original=Double(scalar.text),original.isFinite {return original.bitPattern}
            let scaled=number*Double(factor)
            guard scaled.isFinite else {throw invalid()}
            return scaled.bitPattern
        }
        let parts=text.split(separator:".",omittingEmptySubsequences:false)
        guard (1...2).contains(parts.count),!parts[0].isEmpty,parts[0].allSatisfy({$0.isASCII && $0.isNumber}),let whole=UInt64(parts[0]),whole<=maximum else {throw invalid()}
        let digits=String(factor).count-1
        var fraction:UInt64=0
        if parts.count==2 {
            guard factor>1,!parts[1].isEmpty,parts[1].count<=digits,parts[1].allSatisfy({$0.isASCII && $0.isNumber}),let parsed=UInt64(parts[1]) else {throw invalid()}
            fraction=parsed
            for _ in parts[1].count..<digits {fraction*=10}
        }
        guard whole>=minimum,whole<maximum || (whole==maximum && fraction==0) else {throw invalid()}
        let product=whole.multipliedReportingOverflow(by:factor),sum=product.partialValue.addingReportingOverflow(fraction)
        guard !product.overflow,!sum.overflow else {throw invalid()}
        let limit:UInt64
        switch scalar.type {case 1,8:limit=UInt64(UInt32.max);case 7:limit=UInt64(Int32.max);case 9:limit=UInt64(Int64.max);case 10:limit=UInt64.max;default:throw invalid()}
        guard sum.partialValue<=limit else {throw invalid()}
        return sum.partialValue
    }
}
