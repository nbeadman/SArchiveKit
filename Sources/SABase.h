/*
 *  SABase.h
 *  SArchiveKit
 *
 *  Created by Jean-Daniel Dupas on 16/09/09.
 *  Copyright 2009 Ninsight. All rights reserved.
 *
 */

#if !defined(__SARCHIVE_BASE_H)
#define __SARCHIVE_BASE_H 1

#if !defined(SA_VISIBLE)
	#define SA_VISIBLE __attribute__((visibility("default")))
#endif

#if !defined(SA_HIDDEN)
	#define SA_HIDDEN __attribute__((visibility("hidden")))
#endif

#if defined(__cplusplus)
	#define __inline__ inline
	#define SA_PRIVATE extern "C" SA_HIDDEN
	#define SA_EXPORT extern "C" SA_VISIBLE
#else
	#define SA_PRIVATE extern SA_HIDDEN
	#define SA_EXPORT extern SA_VISIBLE
#endif

#if !defined(SA_CLASS_EXPORT)
	#if __LP64__
		#define SA_CLASS_PRIVATE SA_HIDDEN
		#define SA_CLASS_EXPORT SA_VISIBLE
	#else
		#define SA_CLASS_EXPORT
		#define SA_CLASS_PRIVATE    
	#endif /* Framework && 64 bits runtime */
#endif

#if !defined(SA_INLINE)
	#if !defined(__NO_INLINE__)
		#define SA_INLINE static __inline__ __attribute__((always_inline))
	#else
		#define SA_INLINE static __inline__
	#endif /* No inline */
#endif

#endif /* __SARCHIVE_BASE_H */
