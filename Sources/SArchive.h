/*
 *  SArchive.h
 *  SArchiveKit
 *
 *  Created by Jean-Daniel Dupas.
 *  Copyright (c) 2008 Jean-Daniel Dupas. All rights reserved.
 */

#include <Security/Security.h>
#import <SArchiveKit/SABase.h>

/* setting owner/group behavior */
SARCHIVE_EXPORT NSString * const SArchiveOptionOwnershipBehaviourKey;
/* set owner/group based on names */
SARCHIVE_EXPORT NSString * const SArchiveOptionOwnershipSymbolic;
/* set owner/group based on uid/gid */
SARCHIVE_EXPORT NSString * const SArchiveOptionOwnershipNumeric;

/* Save setuid/setgid bits */
SARCHIVE_EXPORT NSString * const SArchiveOptionSaveSUID;

SARCHIVE_EXPORT NSString * const SArchiveOptionValueTrue;
SARCHIVE_EXPORT NSString * const SArchiveOptionValueFalse;

/* set the toc checksum algorithm */
SARCHIVE_EXPORT NSString * const SArchiveOptionTocCheckSumKey;
/* set the file checksum algorithm */
SARCHIVE_EXPORT NSString * const SArchiveOptionFileCheckSumKey;

SARCHIVE_EXPORT NSString * const SArchiveOptionCheckSumNone;
SARCHIVE_EXPORT NSString * const SArchiveOptionCheckSumSHA1;
SARCHIVE_EXPORT NSString * const SArchiveOptionCheckSumSHA256;
SARCHIVE_EXPORT NSString * const SArchiveOptionCheckSumSHA512;
SARCHIVE_EXPORT NSString * const SArchiveOptionCheckSumMD5;

/* set the file compression type */
SARCHIVE_EXPORT NSString * const SArchiveOptionCompressionKey;

SARCHIVE_EXPORT NSString * const SArchiveOptionValueGZip;
SARCHIVE_EXPORT NSString * const SArchiveOptionValueBZip;
SARCHIVE_EXPORT NSString * const SArchiveOptionValueLZMA;

SARCHIVE_EXPORT NSString * const SArchiveOptionIncludedProperty;
SARCHIVE_EXPORT NSString * const SArchiveOptionExcludedProperty;

/* Read io buffer size */
SARCHIVE_EXPORT NSString * const SArchiveOptionReadBufferSize;

/* Coalesce identical heap blocks */
SARCHIVE_EXPORT NSString * const SArchiveOptionCoalesce;
/* Hardlink identical files */
SARCHIVE_EXPORT NSString * const SArchiveOptionLinkSame;

@class SArchiveSignature;
@protocol SArchiveHandler;
@class SArchiveFile, SArchiveDocument;

SARCHIVE_OBJC_EXPORT
@interface SArchive : NSObject <NSFastEnumeration>

- (instancetype)initWithURL:(NSURL *)anURL;
- (instancetype)initWithURL:(NSURL *)anURL writable:(BOOL)flag;

@property(nonatomic, readonly) NSURL *URL;

- (void)close;

/* size after extraction */
@property(nonatomic, readonly) uint64_t size;
@property(nonatomic, readonly) NSUInteger fileCount;

/*!
 @discussion deep enumerator
 */
- (NSEnumerator *)fileEnumerator;

@property(nonatomic, readonly) NSArray *rootFiles;

- (SArchiveFile *)fileWithName:(NSString *)name;

- (NSString *)valueForOption:(NSString *)key;
- (void)setValue:(NSString *)opt forOption:(NSString *)key;

- (BOOL)boolValueForOption:(NSString *)key;
- (void)setBoolValue:(BOOL)value forOption:(NSString *)key;

- (SArchiveFile *)addFileAtURL:(NSURL *)url;
- (SArchiveFile *)addFileAtURL:(NSURL *)url name:(NSString *)name parent:(SArchiveFile *)parent;

- (SArchiveFile *)addFileWithName:(NSString *)name content:(NSData *)data parent:(SArchiveFile *)parent;
- (SArchiveFile *)addFolderWithName:(NSString *)name properties:(NSDictionary *)props parent:(SArchiveFile *)parent;

- (SArchiveFile *)addFileWrapper:(NSFileWrapper *)aWrapper parent:(SArchiveFile *)parent;

#pragma mark Sub Document
- (SArchiveDocument *)documentWithName:(NSString *)name;
- (SArchiveDocument *)addDocumentWithName:(NSString *)name;

#pragma mark Signatures
@property(nonatomic, readonly) NSArray *signatures;

- (SArchiveSignature *)addSignature:(SecIdentityRef)identity;
- (SArchiveSignature *)addSignature:(SecIdentityRef)identity includeCertificate:(BOOL)include;

/*!
 @method
 @param handler should implements 
 <code>- (void)archive:(SArchive *)manager willProcessFile:(SArchiveFile *)path</code> and
 <code>- (BOOL)archive:(SArchive *)manager shouldProceedAfterError:(NSError *)anError severity:(SArchiveErrorLevel)severity</code>.
 keys: @"ArchiveFile".
 */
- (BOOL)extractAtURL:(NSURL *)anURL handler:(id<SArchiveHandler>)handler;

/* cancel background extraction */
- (void)cancel;

@end

SARCHIVE_EXPORT NSString * const SArchiveErrorDomain;

typedef NS_ENUM(NSInteger, SArchiveErrorLevel) {
	kSArchiveLevelDebug    = 1,
	kSArchiveLevelInfo     = 2,
	kSArchiveLevelNormal   = 3,
	kSArchiveLevelWarning  = 4,
	kSArchiveLevelNonFatal = 5,
	kSArchiveLevelFatal    = 6,
};

/* Extraction */
@protocol SArchiveHandler <NSObject>
@optional
- (BOOL)archive:(SArchive *)archive shouldProcessFile:(SArchiveFile *)file;
- (void)archive:(SArchive *)archive willProcessFile:(SArchiveFile *)file;
//- (void)archive:(SArchive *)archive extractingFile:(SArchiveFile *)file progress:(CGFloat)progress;

- (void)archive:(SArchive *)archive didExtractFile:(SArchiveFile *)file atURL:(NSURL *)url;

- (void)archive:(SArchive *)archive didExtractContent:(BOOL)result atURL:(NSURL *)url;

- (BOOL)archive:(SArchive *)archive shouldProceedAfterError:(NSError *)anError severity:(SArchiveErrorLevel)severity;

@end

