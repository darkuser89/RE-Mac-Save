// Read-only metadata probe for the user's installed single-player games.
// No hooks, game calls, save writes, task attachment or protection changes.
#import <Foundation/Foundation.h>
#import <mach-o/dyld.h>
#import <mach-o/loader.h>
#import <mach/mach_vm.h>
#import <CommonCrypto/CommonCryptor.h>
#include <unistd.h>

static BOOL readBytes(uintptr_t address,void *buffer,size_t size) {
    if(address<0x10000 || !size || size>4096)return NO;
    mach_vm_size_t copied=0;
    return mach_vm_read_overwrite(mach_task_self(),address,size,(mach_vm_address_t)buffer,&copied)==KERN_SUCCESS && copied==size;
}
static uint64_t readPointer(uintptr_t address) {uint64_t value=0;readBytes(address,&value,8);return value;}
static NSString *hexBytes(uintptr_t address,size_t length) {
    uint8_t bytes[256];if(length>sizeof(bytes) || !readBytes(address,bytes,length))return @"";
    NSMutableString *text=[NSMutableString new];for(size_t i=0;i<length;i++)[text appendFormat:@"%02x",bytes[i]];return text;
}
static int64_t signedBits(uint64_t value,unsigned bits) {return (int64_t)(value<<(64-bits))>>(64-bits);}

// Interpret only address calculations and loads of a straight-line getter.
// Never execute the function or write into the game.
static uintptr_t returnedPointer(uintptr_t getter) {
    uintptr_t registers[32]={0};
    for(unsigned i=0;i<16;i++) {
        uint32_t op=0;uintptr_t pc=getter+i*4;if(!readBytes(pc,&op,4))return 0;
        unsigned target=op&31,base=(op>>5)&31;
        if(op==0xd503201f)continue;
        if(op==0xd65f03c0)return registers[0];
        if((op&0x9f000000)==0x90000000) {
            uint64_t imm=(((uint64_t)op>>5)&0x7ffff)<<2 | ((op>>29)&3);
            registers[target]=(pc&~(uintptr_t)4095)+signedBits(imm,21)*4096;
        } else if((op&0xffc00000)==0x91000000) {
            if(!registers[base])return 0;registers[target]=registers[base]+((op>>10)&4095);
        } else if((op&0xffc00000)==0xf9400000) {
            if(!registers[base])return 0;registers[target]=readPointer(registers[base]+((op>>10)&4095)*8);
        } else return 0;
    }
    return 0;
}
static NSData *verifiedKey(uintptr_t resource,NSDictionary *spec) {
    uint32_t count=0;uint8_t bytes[56],marker[24];
    if(!resource || !readBytes(resource+0x1c,&count,4) || count<4 || count>56 || !readBytes(resource+0x20,bytes,count))return nil;
    NSFileHandle *file=[NSFileHandle fileHandleForReadingAtPath:spec[@"localSave"]];
    if(!file)return nil;
    NSData *header=[file readDataOfLength:24];[file closeFile];
    if(header.length!=24 || memcmp(header.bytes,"DSSS",4))return nil;
    memcpy(marker,header.bytes,24);
    uint8_t input[8],output[16],plain[8];
    for(unsigned i=0;i<8;i++)input[i]=marker[16+(i&~3)+(3-(i&3))];
    size_t moved=0;
    if(CCCrypt(kCCDecrypt,kCCAlgorithmBlowfish,kCCOptionECBMode,bytes,count,NULL,input,8,output,16,&moved)!=kCCSuccess || moved!=8)return nil;
    for(unsigned i=0;i<8;i++)plain[i]=output[(i&~3)+(3-(i&3))];
    if(memcmp(plain,"DSSSDSSS",8))return nil;
    return [NSData dataWithBytes:bytes length:count];
}

static void inspect(void) {
    @autoreleasepool {
        const char *specText=getenv("RESAVE_READ_PROBE_SPEC"),*descriptor=getenv("RESAVE_READ_PROBE_FD");
        if(!specText || !descriptor)return;
        int fd=atoi(descriptor);if(fd<3 || fd>1024)return;
        NSDictionary *spec=[NSJSONSerialization JSONObjectWithData:[NSData dataWithBytes:specText length:strlen(specText)] options:0 error:NULL];
        if(![spec isKindOfClass:NSDictionary.class] || ![NSBundle.mainBundle.bundleIdentifier isEqual:spec[@"bundle"]])return;
        const struct mach_header_64 *header=NULL;intptr_t slide=0;NSString *uuid=nil;
        uintptr_t textStart=0,textEnd=0;
        for(uint32_t i=0;i<_dyld_image_count();i++) {
            const struct mach_header_64 *candidate=(void *)_dyld_get_image_header(i);
            if(candidate && candidate->magic==MH_MAGIC_64 && candidate->filetype==MH_EXECUTE){header=candidate;slide=_dyld_get_image_vmaddr_slide(i);break;}
        }
        if(!header || header->cputype!=CPU_TYPE_ARM64 || header->ncmds>4096 || header->sizeofcmds>1024*1024)return;
        const uint8_t *commands=(void *)(header+1);uint32_t cursor=0;
        for(uint32_t i=0;i<header->ncmds;i++) {
            if(cursor>header->sizeofcmds || header->sizeofcmds-cursor<8)return;
            struct load_command command;memcpy(&command,commands+cursor,8);
            if(command.cmdsize<8 || command.cmdsize>header->sizeofcmds-cursor)return;
            if(command.cmd==LC_UUID && command.cmdsize==sizeof(struct uuid_command)) {
                struct uuid_command u;memcpy(&u,commands+cursor,sizeof(u));uuid=[[NSUUID alloc]initWithUUIDBytes:u.uuid].UUIDString;
            }
            if(command.cmd==LC_SEGMENT_64 && command.cmdsize>=sizeof(struct segment_command_64)) {
                struct segment_command_64 segment;memcpy(&segment,commands+cursor,sizeof(segment));
                if(!strcmp(segment.segname,"__TEXT")){textStart=slide+segment.vmaddr;textEnd=textStart+segment.vmsize;}
            }
            cursor+=command.cmdsize;
        }
        if(![uuid isEqual:spec[@"uuid"]] || !textStart || textEnd<=textStart)return;
        uintptr_t tdb=slide+[spec[@"tdb"] unsignedLongLongValue];
        uint32_t index=[spec[@"getterIndex"] unsignedIntValue],owner=[spec[@"getterOwner"] unsignedIntValue];
        for(unsigned attempt=0;attempt<180;attempt++) {
            uint32_t prefix[2]={0};if(!readBytes(tdb,prefix,8) || prefix[0]!=0x424454 || prefix[1]!=[spec[@"version"] unsignedIntValue])return;
            uintptr_t methods=readPointer(tdb+[spec[@"methodsHeaderOffset"] unsignedIntValue]);uint32_t row[3]={0};
            if(methods==tdb+[spec[@"methodsOffset"] unsignedLongLongValue] && index<[spec[@"methodCount"] unsignedIntValue] && readBytes(methods+index*12,row,12) && (row[0]&0x7ffff)==owner && row[2]) {
                uintptr_t getter=slide+[spec[@"methodBase"] unsignedLongLongValue]+(int32_t)row[2];
                if(getter<textStart || getter>textEnd-128)return;
                NSMutableArray *functions=[NSMutableArray new];
                NSMutableArray<NSNumber *> *addresses=[NSMutableArray arrayWithObject:@(getter)];
                // One level of direct callees, only from the exact key getter.
                uint32_t instructions[32];
                if(readBytes(getter,instructions,sizeof(instructions)))for(unsigned i=0;i<32 && addresses.count<5;i++) {
                    uint32_t op=instructions[i];if((op&0xfc000000)!=0x94000000)continue;
                    uintptr_t target=getter+i*4+signedBits(op&0x3ffffff,26)*4;
                    if(target>=textStart && target<textEnd-128 && ![addresses containsObject:@(target)])[addresses addObject:@(target)];
                }
                for(NSNumber *number in addresses) {
                    uintptr_t address=number.unsignedLongLongValue;
                    [functions addObject:@{@"address":@(address-slide),@"code":hexBytes(address,128)}];
                }
                NSData *key=verifiedKey(returnedPointer(getter),spec);
                if(!key && attempt<179){usleep(500000);continue;}
                NSMutableDictionary *result=[@{@"game":spec[@"id"],@"uuid":uuid,@"slide":@(slide),@"getter":@(getter-slide),@"functions":functions,@"readOnly":@YES,@"keyVerified":@(key!=nil),@"gameHome":NSHomeDirectory()} mutableCopy];
                if(key){result[@"keyBase64"]=[key base64EncodedStringWithOptions:0];result[@"keyLength"]=@(key.length);}
                NSData *data=[NSJSONSerialization dataWithJSONObject:result options:NSJSONWritingPrettyPrinted error:NULL];
                if(data.length<16384) {write(fd,data.bytes,data.length);write(fd,"\n",1);}
                close(fd);return;
            }
            usleep(500000);
        }
        close(fd);
    }
}
__attribute__((constructor)) static void startReadProbe(void) {
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY,0),^{inspect();});
}
