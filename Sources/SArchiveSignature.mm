/*
 *  SArchiveSignature.m
 *  SArchiveKit
 *
 *  Created by Jean-Daniel Dupas.
 *  Copyright (c) 2008 Jean-Daniel Dupas. All rights reserved.
 */

#import <SArchiveKit/SArchiveSignature.h>

#import "SArchiveXar.h"

NSString * const kSArchiveSignatureSHA1WithRSA = @"RSA"; // Must Match Apple defined type.

static
bool WBSecTransformSetDigest(SecTransformRef trans, CFTypeRef digestAlg, CFIndex digestBitLength, CFErrorRef *error) {
  if (digestAlg) {
    if (!SecTransformSetAttribute(trans, kSecDigestTypeAttribute, digestAlg, error))
      return false;

    if (digestBitLength > 0) {
      spx::unique_cfptr<CFNumberRef> length(CFNumberCreate(kCFAllocatorDefault, kCFNumberCFIndexType, &digestBitLength));
      if (!SecTransformSetAttribute(trans, kSecDigestLengthAttribute, length.get(), error))
        return false;
    }
  }

  return true;
}

static
SecTransformRef WBSecVerifyTransformCreate(SecKeyRef pkey, CFDataRef signature, CFTypeRef digestAlg, CFIndex digestBitLength, CFErrorRef *error) {
  spx::unique_cfptr<SecTransformRef> trans(SecVerifyTransformCreate(pkey, signature, error));
  if (trans && !WBSecTransformSetDigest(trans.get(), digestAlg, digestBitLength, error))
    return nullptr;
  return trans.release();
}

static
CFBooleanRef WBSecurityVerifyDigestSignature(CFDataRef data, CFDataRef signature, SecKeyRef pubKey, CFTypeRef digestAlg, CFIndex digestBitLength, CFErrorRef *error) {
  spx::unique_cfptr<SecTransformRef> trans(WBSecVerifyTransformCreate(pubKey, signature, digestAlg, digestBitLength, error));
  if (trans &&
      SecTransformSetAttribute(trans.get(), kSecInputIsAttributeName, kSecInputIsDigest, error) &&
      SecTransformSetAttribute(trans.get(), kSecTransformInputAttributeName, data, error))
    return static_cast<CFBooleanRef>(SecTransformExecute(trans.get(), error));
  return nullptr;
}

static
SecTransformRef WBSecSignTransformCreate(SecKeyRef pkey, CFTypeRef digestAlg, CFIndex digestBitLength, CFErrorRef *error) {
  spx::unique_cfptr<SecTransformRef> trans(SecSignTransformCreate(pkey, error));
  if (trans && !WBSecTransformSetDigest(trans.get(), digestAlg, digestBitLength, error))
    return nullptr;
  return trans.release();
}

static
CFDataRef WBSecuritySignDigest(CFDataRef digest, SecKeyRef pkey, CFTypeRef digestAlg, CFIndex digestBitLength, CFErrorRef *error) {
  spx::unique_cfptr<SecTransformRef> sign(WBSecSignTransformCreate(pkey, digestAlg, digestBitLength, error));
  if (sign &&
      SecTransformSetAttribute(sign.get(), kSecInputIsAttributeName, kSecInputIsDigest, error) &&
      SecTransformSetAttribute(sign.get(), kSecTransformInputAttributeName, digest, error))
    return static_cast<CFDataRef>(SecTransformExecute(sign.get(), error));
  return nullptr;
}

@implementation SArchiveSignature

- (instancetype)initWithSignature:(xar_signature_t)ptr {
  if (self = [super init]) {
    _signature = ptr;
  }
  return self;
}

- (void)dealloc {
  if (_identity)
    CFRelease(_identity);
  [super dealloc];
}

- (NSString *)type {
  return _signature ? [NSString stringWithUTF8String:xar_signature_type(_signature)] : nil;
}

- (NSArray *)certificates {
  if (!_signature) return nil;
  
  uint32_t count = xar_signature_get_x509certificate_count(_signature);
  if (!count) return [NSArray array];
  
  NSMutableArray *certs = [[NSMutableArray alloc] initWithCapacity:count];
  for (uint32 idx = 0; idx < count; idx++) {
    uint32_t datalen = 0;
    const uint8_t *data = NULL;
    if (0 == xar_signature_get_x509certificate_data(_signature, idx, &data, &datalen)) {
      spx::unique_cfptr<CFDataRef> certdata(CFDataCreateWithBytesNoCopy(kCFAllocatorDefault, data, datalen, kCFAllocatorNull));
      if (certdata) {
        spx::unique_cfptr<SecCertificateRef> cert(SecCertificateCreateWithData(kCFAllocatorDefault, certdata.get()));
        if (cert)
          [certs addObject:SPXCFToNSType(cert.get())];
      }
    }
  }
  return [certs autorelease];
}

- (BOOL)addCertificate:(SecCertificateRef)cert {
  if (!_signature)
    return NO;
  
  spx::unique_cfptr<CFDataRef> certdata(SecCertificateCopyData(cert));
  if (certdata) {
    return 0 == xar_signature_add_x509certificate(_signature, CFDataGetBytePtr(certdata.get()), (uint32_t)CFDataGetLength(certdata.get()));
  } else {
    return NO;
  }
}

- (BOOL)verify:(SecCertificateRef)certificate {
  SecKeyRef pkey = NULL;
  CFBooleanRef valid = nullptr;
  NSData *data = NULL, *signature = NULL;
  OSStatus err = SecCertificateCopyPublicKey(certificate, &pkey);
  if (noErr == err)
    err = [self getDigest:&data signature:&signature];
  if (noErr == err) {
    valid = WBSecurityVerifyDigestSignature(SPXNSToCFData(data), SPXNSToCFData(signature), pkey, kSecDigestSHA1, 0, NULL);
  }
  if (pkey) CFRelease(pkey);
  
  return valid != nullptr && CFBooleanGetValue(valid);
}

- (OSStatus)getDigest:(NSData **)digest signature:(NSData **)signdata {
  if (!_signature) return noErr;
  
  uint8_t *data = NULL, *signed_data = NULL;
  uint32_t length = 0, signed_length = 0;
  int err = xar_signature_copy_signed_data(_signature, &data, &length, &signed_data, &signed_length, NULL);
  if (0 == err) {
    if (digest) *digest = [NSData dataWithBytesNoCopy:data length:length freeWhenDone:YES];
    if (signdata) *signdata = [NSData dataWithBytesNoCopy:signed_data length:signed_length freeWhenDone:YES];
  }
  return err;
}


#pragma mark Xar Interface
static
int32_t _SArchiveSigner(xar_signature_t sig, void *context, uint8_t *data, uint32_t length, uint8_t **signed_data, uint32_t *signed_len);

+ (SArchiveSignature *)signatureWithIdentity:(SecIdentityRef)identity archive:(xar_t)arch {
  SecKeyRef pkey = NULL;
  size_t signlen = 0;
  SArchiveSignature *signature = nil;
  OSStatus err = SecIdentityCopyPrivateKey(identity, &pkey);
  if (noErr == err) {
    // FIXME: works only for RSA
    signlen = SecKeyGetBlockSize(pkey);
    CFRelease(pkey);
  }
  if (signlen > 0) {
    xar_signature_t sign = xar_signature_new(arch, [kSArchiveSignatureSHA1WithRSA UTF8String], signlen, _SArchiveSigner, identity);
    if (sign) {
      signature = [[SArchiveSignature alloc] initWithSignature:sign];
      signature->_identity = SPXCFRetain(identity);
    }
  }
  return [signature autorelease];
}

@end

#pragma mark -
#pragma mark Signature
int32_t _SArchiveSigner(xar_signature_t sig, void *context, uint8_t *data, uint32_t length, uint8_t **signed_data, uint32_t *signed_len) {
  SecKeyRef pkey = nullptr;
  SecIdentityRef ident = (SecIdentityRef)context;
  OSStatus err = SecIdentityCopyPrivateKey(ident, &pkey);
  if (noErr == err) {
    spx::unique_cfptr<CFDataRef> digest(CFDataCreateWithBytesNoCopy(kCFAllocatorDefault, data, length, kCFAllocatorNull));
    CFDataRef signature = WBSecuritySignDigest(digest.get(), pkey, kSecDigestSHA1, length, nullptr);
    if (signature) {
      *signed_len = (uint32_t)CFDataGetLength(signature);
      *signed_data = static_cast<uint8_t *>(malloc(*signed_len));
      CFDataGetBytes(signature, CFRangeMake(0, *signed_len), *signed_data);
      CFRelease(signature);
    } else {
      err = -1;
    }
    SPXCFRelease(pkey);
  }
  return err;
}
