/*
 *  SArchiveFile.h
 *  SArchiveKit
 *
 *  Created by Jean-Daniel Dupas.
 *  Copyright (c) 2008 Jean-Daniel Dupas. All rights reserved.
 */

#import <SArchiveKit/SABase.h>

typedef NS_ENUM(NSInteger, SArchiveType) {
  kSArchiveTypeUndefined = 0,
  kSArchiveTypeFile,
  kSArchiveTypeSymlink,
  kSArchiveTypeDirectory,
  /* Other types */
  kSArchiveTypeFifo,
  kSArchiveTypeSocket,
  kSArchiveTypeBlockSpecial,
  kSArchiveTypeCharacterSpecial,
  /* Misc */
  kSArchiveTypeWithout,
};

SARCHIVE_OBJC_EXPORT
@interface SArchiveFile : NSObject <NSFastEnumeration>

@property(nonatomic, copy) NSString *path;

@property(nonatomic, readonly) SArchiveType type;
@property(nonatomic, readonly) uint64_t size;

@property(nonatomic, copy) NSString *name;

@property(nonatomic) mode_t posixPermissions;

- (BOOL)verify;
- (BOOL)extract;

- (NSData *)extractContents;
- (BOOL)extractAtURL:(NSURL *)url;

- (NSFileWrapper *)fileWrapper;
- (SArchiveFile *)fileWithName:(NSString *)name;

/* Properties */
- (NSString *)valueForProperty:(NSString *)prop;
- (void)setValue:(NSString *)value forProperty:(NSString *)prop;

/* Attributes */
- (NSString *)valueForAttribute:(NSString *)attr property:(NSString *)prop;
- (void)setValue:(NSString *)value forAttribute:(NSString *)attr property:(NSString *)property;

#pragma mark -
@property(nonatomic, readonly) SArchiveFile *container;

@property(nonatomic, readonly) NSArray *files;
@property(nonatomic, readonly) NSUInteger count;

/* deep enumerator */
- (NSEnumerator *)enumerator;

@end
