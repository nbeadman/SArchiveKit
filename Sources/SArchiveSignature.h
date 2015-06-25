/*
 *  SArchiveSignature.h
 *  SArchiveKit
 *
 *  Created by Jean-Daniel Dupas.
 *  Copyright (c) 2008 Jean-Daniel Dupas. All rights reserved.
 */

#import <Security/Security.h>

#import <SArchiveKit/SABase.h>

SARCHIVE_EXPORT
NSString * const kSArchiveSignatureSHA1WithRSA;

SARCHIVE_OBJC_EXPORT
@interface SArchiveSignature : NSObject

@property(nonatomic, readonly) SecIdentityRef identity;

@property(nonatomic, readonly) NSArray *certificates;

- (BOOL)addCertificate:(SecCertificateRef)cert;

- (BOOL)verify:(SecCertificateRef)certificate;
- (OSStatus)getDigest:(NSData **)digest signature:(NSData **)signdata;

@end
