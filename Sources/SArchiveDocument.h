/*
 *  SArchiveDocument.h
 *  SArchiveKit
 *
 *  Created by Jean-Daniel Dupas.
 *  Copyright (c) 2008 Jean-Daniel Dupas. All rights reserved.
 */

#import <SArchiveKit/SABase.h>

SARCHIVE_OBJC_EXPORT
@interface SArchiveDocument : NSObject {
@private
  void *sa_ptr;
  void *sa_arch;
  NSString *sa_name;
}

@property(nonatomic, copy) NSString *name;

/* Properties */
- (NSString *)valueForProperty:(NSString *)prop;
- (void)setValue:(NSString *)value forProperty:(NSString *)prop;

/* Attributes */
- (NSString *)valueForAttribute:(NSString *)attr property:(NSString *)prop;
- (void)setValue:(NSString *)value forAttribute:(NSString *)attr property:(NSString *)property;

@end
