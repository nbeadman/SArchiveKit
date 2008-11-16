/*
 *  SArchiveSignature.m
 *  SArchiveKit
 *
 *  Created by Jean-Daniel Dupas.
 *  Copyright (c) 2008 Jean-Daniel Dupas. All rights reserved.
 */

#import <SArchiveKit/SArchiveSignature.h>

#import "SArchiveXar.h"

NSString * const kSArchiveSignatureSHA1WithRSA = @"SHA1withRSA";

static
OSStatus WBSecurityVerifySignature(SecKeyRef pubKey, const CSSM_DATA *digest, const CSSM_DATA *signature, Boolean *valid);
static
OSStatus WBSecuritySignData(SecKeyRef privKey, SecCredentialType credentials, const CSSM_DATA *digest, CSSM_DATA *signature);

@implementation SArchiveSignature

- (void)dealloc {
  if (sa_identity) CFRelease(sa_identity);
  [super dealloc];
}

- (SecIdentityRef)identity {
  return sa_identity;
}

- (NSString *)type {
  return sa_ptr ? [NSString stringWithUTF8String:xar_signature_type(sa_sign)] : nil;
}

- (NSArray *)certificates {
  if (!sa_ptr) return nil;
  
  uint32_t count = xar_signature_get_x509certificate_count(sa_sign);
  if (!count) return [NSArray array];
  
  NSMutableArray *certs = [[NSMutableArray alloc] initWithCapacity:count];
  for (uint32 idx = 0; idx < count; idx++) {
    uint32_t datalen = 0;
    const uint8_t *data = NULL;
    if (0 == xar_signature_get_x509certificate_data(sa_sign, idx, &data, &datalen)) {
      SecCertificateRef cert = NULL;
      const CSSM_DATA certdata = { datalen, (uint8_t *)data };
      OSStatus err = SecCertificateCreateFromData(&certdata, CSSM_CERT_X_509v3, CSSM_CERT_ENCODING_BER, &cert);
      if (noErr == err) {
        [certs addObject:(id)cert];
        CFRelease(cert);
      }
    }
  }
  return [certs autorelease];
}

- (OSStatus)addCertificate:(SecCertificateRef)cert {
  if (!sa_ptr) return paramErr;
  
  CSSM_DATA certdata = { 0, NULL };
  OSStatus err = SecCertificateGetData(cert, &certdata);
  if (noErr == err) {
    err = xar_signature_add_x509certificate(sa_sign, certdata.Data, (uint32_t)certdata.Length);
  }
  return err;
}

- (BOOL)verify:(SecCertificateRef)certificate {
  SecKeyRef pkey = NULL;
  Boolean valid = false;
  NSData *data = NULL, *signature = NULL;
  OSStatus err = SecCertificateCopyPublicKey(certificate, &pkey);
  if (noErr == err)
    err = [self getDigest:&data signature:&signature];
  if (noErr == err) {
    const CSSM_DATA cdata = { [data length], (UInt8 *)[data bytes] };
    const CSSM_DATA csign = { [signature length], (UInt8 *)[signature bytes] };
    err = WBSecurityVerifySignature(pkey, &cdata, &csign, &valid);
  }
  if (pkey) CFRelease(pkey);
  
  return valid;
}

- (OSStatus)getDigest:(NSData **)digest signature:(NSData **)signdata {
  if (!sa_ptr) return noErr;
  
  uint8_t *data = NULL, *signed_data = NULL;
  uint32_t length = 0, signed_length = 0;
  int err = xar_signature_copy_signed_data(sa_sign, &data, &length, &signed_data, &signed_length);
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
  uint32_t signlen = 0;
  SArchiveSignature *signature = nil;
  OSStatus err = SecIdentityCopyPrivateKey(identity, &pkey);
  if (noErr == err) {
    const CSSM_KEY *key = NULL;
    err = SecKeyGetCSSMKey(pkey, &key);
    if (noErr == err)
      signlen = key->KeyHeader.LogicalKeySizeInBits / 8;
    CFRelease(pkey);
  }
  if (signlen > 0) {
    xar_signature_t sign = xar_signature_new(arch, [kSArchiveSignatureSHA1WithRSA UTF8String], signlen, _SArchiveSigner, identity);
    if (sign) {
      signature = [[SArchiveSignature alloc] initWithArchive:arch signature:sign];
      [signature setIndentity:identity];
    }
  }
  return [signature autorelease];
}

- (id)initWithArchive:(xar_t)arch signature:(xar_signature_t)ptr {
  if (self = [super init]) {
    [self setArchive:arch];
    [self setSignature:ptr];
  }
  return self;
}

- (xar_signature_t)signature {
  return sa_sign;
}
- (void)setSignature:(xar_signature_t)signature {
  sa_ptr = (void *)signature;
}

- (xar_t)archive {
  return sa_xar;
}
- (void)setArchive:(xar_t)arch {
  sa_arch = (void *)arch;
}

- (void)setIndentity:(SecIdentityRef)identity {
  NSParameterAssert(sa_identity == NULL);
  sa_identity = identity;
  CFRetain(sa_identity);
}

@end

#pragma mark -
#pragma mark Signature
int32_t _SArchiveSigner(xar_signature_t sig, void *context, uint8_t *data, uint32_t length, uint8_t **signed_data, uint32_t *signed_len) {
  SecKeyRef pkey = NULL;
  uint32_t signlen = 0;
  SecIdentityRef ident = (SecIdentityRef)context;
  OSStatus err = SecIdentityCopyPrivateKey(ident, &pkey);
  if (noErr == err) {
    const CSSM_KEY *key = NULL;
    err = SecKeyGetCSSMKey(pkey, &key);
    if (noErr == err)
      signlen = key->KeyHeader.LogicalKeySizeInBits / 8;
  }
  if (signlen > 0) {
    CSSM_DATA digest = { length, data };
    CSSM_DATA signature = { signlen, malloc(signlen) };
    err = WBSecuritySignData(pkey, kSecCredentialTypeDefault, &digest, &signature);
    if (noErr == err) {
      *signed_len = (uint32_t)signature.Length;
      *signed_data = signature.Data;
    }
  }
  if (pkey) CFRelease(pkey);
  
  return err;
}

#pragma mark -
#pragma mark ShadowKit
static
OSStatus WBSecurityCreateSignatureContext(SecKeyRef privKey, SecCredentialType credentials, CSSM_CC_HANDLE *ccHandle) {
  OSStatus err = noErr;
  CSSM_CSP_HANDLE cspHandle = 0;
  const CSSM_KEY *privkey = NULL;
  const CSSM_ACCESS_CREDENTIALS *credits = NULL;
  
  /* retreive cssm objects */
  err = SecKeyGetCSSMKey(privKey, &privkey);
  require_noerr(err, bail);
  err = SecKeyGetCSPHandle(privKey, &cspHandle);
  require_noerr(err, bail);
  err = SecKeyGetCredentials(privKey, CSSM_ACL_AUTHORIZATION_SIGN, credentials, &credits);
  require_noerr(err, bail);
  
  /* create cssm context */
  err = CSSM_CSP_CreateSignatureContext(cspHandle, CSSM_ALGID_SHA1WithRSA, credits, privkey, ccHandle);
  require_noerr(err, bail);
  
bail:
    return err;
}
static
OSStatus WBSecurityCreateVerifyContext(SecKeyRef pubKey, CSSM_CC_HANDLE *ccHandle) {
  OSStatus err = noErr;
  CSSM_CSP_HANDLE cspHandle = 0;
  const CSSM_KEY *pubkey = NULL;
  
  /* retreive pubkey and csp */
  err = SecKeyGetCSSMKey(pubKey, &pubkey);
  require_noerr(err, bail);
  err = SecKeyGetCSPHandle(pubKey, &cspHandle);
  require_noerr(err, bail);
  
  /* create cssm context */
  err = CSSM_CSP_CreateSignatureContext(cspHandle, CSSM_ALGID_SHA1WithRSA, NULL, pubkey, ccHandle);
  require_noerr(err, bail);
  
bail:
    return err;
}

static
OSStatus WBSecuritySignData(SecKeyRef privKey, SecCredentialType credentials, const CSSM_DATA *digest, CSSM_DATA *signature) {
  OSStatus err = noErr;
  CSSM_CC_HANDLE ccHandle = 0;
  
  err = WBSecurityCreateSignatureContext(privKey, credentials, &ccHandle);
  require_noerr(err, bail);
  err = CSSM_SignData(ccHandle, digest, 1, CSSM_ALGID_NONE, signature);
  require_noerr(err, bail);
  
bail:
    /* cleanup */
    if (ccHandle) CSSM_DeleteContext(ccHandle);
  
  return err;
}

static
OSStatus WBSecurityVerifySignature(SecKeyRef pubKey, const CSSM_DATA *digest, const CSSM_DATA *signature, Boolean *valid) {
  OSStatus err = noErr;
  CSSM_CC_HANDLE ccHandle = 0;
  
  /* retreive pubkey and csp */
  err = WBSecurityCreateVerifyContext(pubKey, &ccHandle);
  require_noerr(err, bail);
  
  /* verify data */
  err = CSSM_VerifyData(ccHandle, digest, 1, CSSM_ALGID_NONE, signature);
  if (CSSMERR_CSP_VERIFY_FAILED == err) {
    err = noErr;
    *valid = FALSE;
  } else if (noErr == err) {
    *valid = TRUE;
  }
  require_noerr(err, bail);
  
bail:
    /* cleanup */
    if (ccHandle) CSSM_DeleteContext(ccHandle);
  
  return err;
}
