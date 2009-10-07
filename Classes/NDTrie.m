/*
	NDTrie.m
	NDTrieTest

	Created by Nathan Day on 17/09/09.
	Copyright 2009 Nathan Day. All rights reserved.
*/

#import "NDTrie.h"
#include <string.h>

struct trieNode
{
	NSUInteger						key;
	NSUInteger						count,
									size;
	id								object;
	__strong struct trieNode		** children;
};

static struct trieNode * findNode( struct trieNode *, id, NSUInteger, BOOL, struct trieNode **, NSUInteger *, NSUInteger (*)( id, NSUInteger, BOOL* ));
static BOOL removeObjectForKey( struct trieNode *, id, NSUInteger, BOOL *, NSUInteger (*)( id, NSUInteger, BOOL* ) );
static NSUInteger removeAllChildren( struct trieNode *);
static NSUInteger removeChild( struct trieNode *, id, NSUInteger (*)( id, NSUInteger, BOOL* ) );
static BOOL setObjectForKey( struct trieNode *, id, id, NSUInteger (*)( id, NSUInteger, BOOL* ) );
static void forEveryObjectFromNode( struct trieNode *, BOOL(*)(id,void*), void * );
static BOOL nodesAreEqual( struct trieNode *, struct trieNode * );
static struct trieNode * copyNode( struct trieNode * );

static NSUInteger keyComponentForString( id anObject, NSUInteger anIndex, BOOL * anEnd )
{
	if( anIndex < [anObject length] )
		return [anObject characterAtIndex:anIndex];

	*anEnd = YES;
	return 0;
}

static BOOL _addTrieFunc( NSString * aString, void * aContext )
{
	NDMutableTrie		* theTrie = (NDMutableTrie*)aContext;
	[theTrie addString:aString];
	return YES;
}

@interface NDTrie (Private)
- (struct trieNode*)root;
@end

@implementation NDTrie

+ (id)trie
{
	return [[[self alloc] init] autorelease];
}

+ (id)trieWithArray:(NSArray *)anArray
{
	return [[[self alloc] initWithArray:anArray] autorelease];
}

+ (id)trieWithDictionary:(NSDictionary *)aDictionary
{
	return [[[self alloc] initWithDictionary:aDictionary] autorelease];
}

+ (id)trieWithTrie:(NDTrie *)anAnotherTrie
{
	return [[[self alloc] initWithTrie:anAnotherTrie] autorelease];
}

+ (id)trieWithStrings:(NSString *)aFirstString, ...
{
	NDTrie		* theResult = nil;
	va_list	theArgList;
	va_start( theArgList, aFirstString );
	theResult = [[[self alloc] initWithStrings:aFirstString arguments:theArgList] autorelease];
	va_end( theArgList );
	return theResult;
}

+ (id)trieWithObjectsAndKeys:(id)aFirstObject , ...
{
	NDTrie		* theResult = nil;
	va_list	theArgList;
	va_start( theArgList, aFirstObject );
	theResult = [[[self alloc] initWithObjectsAndKeys:aFirstObject arguments:theArgList] autorelease];
	va_end( theArgList );
	return theResult;
}

+ (id)trieWithContentsOfFile:(NSString *)aPath
{
	return [[[self alloc] initWithContentsOfFile:aPath] autorelease];
}

+ (id)trieWithContentsOfURL:(NSURL *)aURL
{
	return [[[self alloc] initWithContentsOfURL:aURL] autorelease];
}

+ (id)trieWithStrings:(const NSString **)aStrings count:(NSUInteger)aCount
{
	return [[[self alloc] initWithObjects:aStrings forKeys:aStrings count:aCount] autorelease];
}

+ (id)trieWithObjects:(id *)anObjects forKeys:(id *)aKeys count:(NSUInteger)aCount
{
	return [[[self alloc] initWithObjects:anObjects forKeys:aKeys count:aCount] autorelease];
}

- (id)init
{
	if( (self = [super init]) != nil )
		root = calloc( 1, sizeof(struct trieNode) );
	return self;
}

- (id)initWithArray:(NSArray *)anArray
{
	if( (self = [self init]) != nil )
	{
#if __OBJC2__
		for( NSString * theString in anArray )
		{
			if( ![theString isKindOfClass:[NSString class]] )
				@throw [NSException exceptionWithName:NSInvalidArgumentException reason:[NSString stringWithFormat:@"An attempt was made to add and object of class $@ to a NDTrie", [theString class]] userInfo:nil];
			count += setObjectForKey( [self root], theString, theString, keyComponentForString );
		}
#else
		for( NSUInteger i = 0, c = [anArray count]; i < c; i++ )
		{
			NSString		* theString = [anArray objectAtIndex:i];
			if( ![theString isKindOfClass:[NSString class]] )
				@throw [NSException exceptionWithName:NSInvalidArgumentException reason:[NSString stringWithFormat:@"An attempt was made to add and object of class $@ to a NDTrie", [theString class]] userInfo:nil];
			count += setObjectForKey( [self root], theString, theString );
		}
#endif
	}
	return self;
}

- (id)initWithDictionary:(NSDictionary *)aDictionary
{
	if( (self = [self init]) != nil )
	{
#if __OBJC2__
		for( NSString * theKey in aDictionary )
		{
			if( ![theKey isKindOfClass:[NSString class]] )
				@throw [NSException exceptionWithName:NSInvalidArgumentException reason:[NSString stringWithFormat:@"An attempt was made to add and object of class $@ to a NDTrie", [theKey class]] userInfo:nil];
			count += setObjectForKey( [self root], [aDictionary objectForKey:theKey], theKey, keyComponentForString );
		}
#else
		NSArray		* theKeysArray = [aDictionary allKeys];
		for( NSUInteger i = 0, c = [theKeysArray count]; i < c; i++ )
		{
			NSString		* theKey = [theKeysArray objectAtIndex:i];
			if( ![theKey isKindOfClass:[NSString class]] )
				@throw [NSException exceptionWithName:NSInvalidArgumentException reason:[NSString stringWithFormat:@"An attempt was made to add and object of class $@ to a NDTrie", [theKey class]] userInfo:nil];
			count += setObjectForKey( [self root], [aDictionary objectForKey:theKey], theKey );
		}
#endif
	}
	return self;
}

- (id)initWithTrie:(NDTrie *)anAnotherTrie
{
	if( (self = [self init]) != nil )
		root = copyNode( [anAnotherTrie root] );
	return self;
}


- (id)initWithStrings:(NSString *)aFirstString, ...
{
	NDTrie		* theResult = nil;
	va_list	theArgList;
	va_start( theArgList, aFirstString );
	theResult = [self initWithStrings:aFirstString arguments:theArgList];
	va_end( theArgList );
	return theResult;
}

- (id)initWithObjectsAndKeys:(NSString *)aFirstObject, ...
{
	NDTrie		* theResult = nil;
	va_list	theArgList;
	va_start( theArgList, aFirstObject );
	theResult = [self initWithObjectsAndKeys:aFirstObject arguments:theArgList];
	va_end( theArgList );
	return theResult;
}

- (id)initWithContentsOfFile:(NSString *)aPath
{
	return [self initWithArray:[NSArray arrayWithContentsOfFile:aPath]];
}

- (id)initWithContentsOfURL:(NSURL *)aURL
{
	return [self initWithArray:[NSArray arrayWithContentsOfURL:aURL]];
}

- (id)initWithStrings:(NSString **)aStrings count:(NSUInteger)aCount
{
	return [self initWithObjects:aStrings forKeys:aStrings count:aCount];
}

- (id)initWithObjects:(id *)anObjects forKeys:(NSString **)aKeys count:(NSUInteger)aCount
{
	if( (self = [self init]) != nil )
	{
		for( NSUInteger i = 0; i < aCount; i++ )
			count += setObjectForKey( [self root], anObjects[i], aKeys[i], keyComponentForString );
	}
	return self;
}

- (id)initWithStrings:(NSString *)aFirstString arguments:(va_list)anArguments
{
	if( (self = [self init]) != nil )
	{
		NSString	* theString = aFirstString;

		do
		{
			if( ![theString isKindOfClass:[NSString class]] )
				@throw [NSException exceptionWithName:NSInvalidArgumentException reason:[NSString stringWithFormat:@"An attempt was made to add and object of class $@ to a NDTrie", [theString class]] userInfo:nil];

			count += setObjectForKey( [self root], theString, theString, keyComponentForString );
		}
		while( (theString = va_arg( anArguments, NSString * ) ) != nil );
	}
	return self;
}

- (id)initWithObjectsAndKeys:(id)aFirstObject arguments:(va_list)anArguments
{
	if( (self = [self init]) != nil )
	{
		NSString	* theObject = aFirstObject;
		
		do
		{
			NSString	* theKey = va_arg( anArguments, NSString * );
			if( theKey == nil )
				@throw [NSException exceptionWithName:NSInvalidArgumentException reason:@"found nil key" userInfo:nil];
			if( ![theKey isKindOfClass:[NSString class]] )
				@throw [NSException exceptionWithName:NSInvalidArgumentException reason:[NSString stringWithFormat:@"An attempt was made to add and object of class $@ to a NDTrie", [theKey class]] userInfo:nil];
			
			count += setObjectForKey( [self root], theObject, theKey, keyComponentForString );
		}
		while( (theObject = va_arg( anArguments, id ) ) != nil );
	}
	return self;
}

- (void)dealloc
{
	removeAllChildren( [self root] );
	free( root );
	[super dealloc];
}

- (void)finalize
{
	removeAllChildren( [self root] );
	free( root );
	[super finalize];
}

- (NSUInteger)count
{
	return count;
}

- (BOOL)containsObjectForKey:(NSString *)aString
{
	struct trieNode		* theNode = findNode( (struct trieNode *)root, aString, 0, NO, NULL, NULL, keyComponentForString );
	return theNode != NULL && theNode->object != nil;
}

- (BOOL)containsObjectForKeyWithPrefix:(NSString *)aString
{
	struct trieNode		* theNode = findNode( (struct trieNode *)root, aString, 0, NO, NULL, NULL, keyComponentForString );
	return theNode != NULL;
}

- (id)objectForKey:(NSString *)aKey
{
	struct trieNode		* theNode = findNode( (struct trieNode *)root, aKey, 0, NO, NULL, NULL, keyComponentForString );
	return theNode != NULL ? theNode->object : nil;
}

static BOOL _addToArrayFunc( id anObject, void * anArray )
{
	[(id)anArray addObject:anObject];
	return YES;
}
- (NSArray *)everyObject
{
	NSMutableArray		* theResult = [NSMutableArray arrayWithCapacity:[self count]];
	forEveryObjectFromNode( [self root], _addToArrayFunc, theResult );
	return theResult;
}

- (NSArray *)everyObjectForKeyWithPrefix:(NSString *)aPrefix
{
	NSMutableArray		* theResult = [NSMutableArray arrayWithCapacity:[self count]];
	struct trieNode		* theNode = [self root];
	if( aPrefix != nil && [aPrefix length] > 0 )
		theNode = findNode( theNode, aPrefix, 0, NO, NULL, NULL, keyComponentForString );
	if( theNode != nil )
		forEveryObjectFromNode( theNode, _addToArrayFunc, theResult );
	return theResult;
}

- (BOOL)isEqualToTrie:(NDTrie *)anOtherTrie
{
	return nodesAreEqual( [self root], [anOtherTrie root] );
}

- (BOOL)isEqual:(id)anObject
{
	return [anObject isKindOfClass:[NDTrie class]] ? [self isEqualToTrie:anObject] : NO;
}

- (void)enumerateObjectsUsingFunction:(BOOL (*)(NSString *))aFunc
{
	forEveryObjectFromNode( [self root], (BOOL(*)(NSString*,void*))aFunc, NULL );
}

- (void)enumerateObjectsForKeysWithPrefix:(NSString*)aPrefix usingFunction:(BOOL (*)(NSString *))aFunc
{
	struct trieNode		* theNode = [self root];
	if( aPrefix != nil && [aPrefix length] > 0 )
		theNode = findNode( theNode, aPrefix, 0, NO, NULL, NULL, keyComponentForString );
	if( theNode != nil )
		forEveryObjectFromNode( theNode, (BOOL(*)(NSString*,void*))aFunc, NULL );
}

- (void)enumerateObjectsUsingFunction:(BOOL (*)(NSString *,void *))aFunc context:(void*)aContext
{
	forEveryObjectFromNode( [self root], aFunc, aContext );
}

- (void)enumerateObjectsForKeysWithPrefix:(NSString*)aPrefix usingFunction:(BOOL (*)(NSString *,void *))aFunc context:(void*)aContext
{
	struct trieNode		* theNode = [self root];
	if( aPrefix != nil && [aPrefix length] > 0 )
		theNode = findNode( theNode, aPrefix, 0, NO, NULL, NULL, keyComponentForString );
	if( theNode != nil )
		forEveryObjectFromNode( theNode, aFunc, aContext );
}

- (BOOL)writeToFile:(NSString *)aPath atomically:(BOOL)anAtomically
{
	return [[self everyObject] writeToFile:aPath atomically:anAtomically];
}

- (BOOL)writeToURL:(NSURL *)aURL atomically:(BOOL)anAtomically
{
	return [[self everyObject] writeToURL:aURL atomically:anAtomically];
}

#ifdef NS_BLOCKS_AVAILABLE
BOOL enumerateFunc( NSString * aString, void * aContext )
{
	BOOL	theStop = NO;
	void (^theBlock)(NSString *, BOOL *) = (void (^)(NSString *, BOOL *))aContext;
	theBlock( aString, &theStop );
	return !theStop;
}
- (void)enumerateObjectsUsingBlock:(void (^)(NSString *, BOOL *))aBlock
{
	forEveryObjectFromNode( [self root], enumerateFunc, (void*)aBlock );
}

- (void)enumerateObjectsForKeysWithPrefix:(NSString*)aPrefix usingBlock:(void (^)(NSString * string, BOOL *stop))aBlock
{
	struct trieNode		* theNode = [self root];
	if( aPrefix != nil && [aPrefix length] > 0 )
		theNode = findNode( theNode, aPrefix, 0, NO, NULL, NULL, keyComponentForString );
	if( theNode != nil )
		forEveryObjectFromNode( theNode, enumerateFunc, (void*)aBlock );
}

struct testData
{
	NSMutableArray * array;
	BOOL (^block)(id, BOOL *);
};
BOOL testFunc( id anObject, void * aContext )
{
	struct testData		* theData = (struct testData*)aContext;
	BOOL				theTestResult = NO;
	if( theData->block( anObject, &theTestResult ) )
		[theData->array addObject:anObject];
	return !theTestResult;
}
- (NSArray *)everyObjectPassingTest:(BOOL (^)(id, BOOL *))aPredicate
{
	struct testData		theData = { [NSMutableArray array], aPredicate };
	forEveryObjectFromNode( [self root], testFunc, (void*)&theData );
	return theData.array;;
}

- (NSArray *)everyObjectForKeyWithPrefix:(NSString*)aPrefix passingTest:(BOOL (^)(id object, BOOL *stop))aPredicate
{
	struct testData		theData = { [NSMutableArray array], aPredicate };
	struct trieNode		* theNode = [self root];
	if( aPrefix != nil && [aPrefix length] > 0 )
		theNode = findNode( theNode, aPrefix, 0, NO, NULL, NULL, keyComponentForString );
	if( theNode != nil )
		forEveryObjectFromNode( theNode, testFunc, (void*)&theData );
	return theData.array;;
}

#endif

- (NSString *)description
{
	return [[self everyObject] description];
}

- (id)copyWithZone:(NSZone *)aZone
{
	return [self isMemberOfClass:[NDTrie class]] ? [self retain] : [[NDTrie allocWithZone:aZone] initWithTrie:self];
}

- (id)mutableCopyWithZone:(NSZone *)aZone
{
	return [[NDMutableTrie allocWithZone:aZone] initWithTrie:self];
}

@end

@implementation NDMutableTrie

- (void)addString:(NSString *)aString
{
	[self setObject:aString forKey:aString];
}

- (void)setObject:(id)anObject forKey:(NSString *)aString;
{
	count += setObjectForKey( [self root], anObject, aString, keyComponentForString );
}

- (void)addStrings:(NSString *)aFirstString, ...
{
	va_list		theArgList;
	NSString	* theString = aFirstString;

	va_start( theArgList, aFirstString );

	do
	{
		if( ![theString isKindOfClass:[NSString class]] )
			@throw [NSException exceptionWithName:NSInvalidArgumentException reason:[NSString stringWithFormat:@"An attempt was made to add and object of class $@ to a NDTrie", [theString class]] userInfo:nil];

		count += setObjectForKey( [self root], theString, theString, keyComponentForString );
	}
	while( (theString = va_arg( theArgList, NSString * ) ) != nil );

	va_end( theArgList );
}

- (void)setObjectsAndKeys:(id)aFirstObject, ...
{
	va_list		theArgList;
	id			theObject = aFirstObject;
	
	va_start( theArgList, aFirstObject );
	
	do
	{
		NSString	* theKey = va_arg( theArgList, id );
		if( theKey == nil )
			@throw [NSException exceptionWithName:NSInvalidArgumentException reason:@"missing key for object" userInfo:nil];
		if( ![theKey isKindOfClass:[NSString class]] )
			@throw [NSException exceptionWithName:NSInvalidArgumentException reason:[NSString stringWithFormat:@"An attempt was made to add and object of class $@ to a NDTrie", [theKey class]] userInfo:nil];
		
		count += setObjectForKey( [self root], theObject, theKey, keyComponentForString );
	}
	while( (theObject = va_arg( theArgList, id ) ) != nil );
	
	va_end( theArgList );
}

- (void)addStrings:(NSString **)aStrings count:(NSUInteger)aCount
{
	for( NSUInteger i = 0; i < aCount; i++ )
		count += setObjectForKey( [self root], aStrings[i], aStrings[i], keyComponentForString );
}

- (void)setObjects:(id *)anObjects forKeys:(id *)aKeys count:(NSUInteger)aCount
{
	for( NSUInteger i = 0; i < aCount; i++ )
		count += setObjectForKey( [self root], anObjects[i], aKeys[i], keyComponentForString );
}

- (void)addTrie:(NDTrie *)aTrie
{
	[aTrie enumerateObjectsUsingFunction:_addTrieFunc context:(void*)self];
}

- (void)addArray:(NSArray *)anArray
{
#if __OBJC2__
	for( NSString * theString in anArray )
	{
		if( ![theString isKindOfClass:[NSString class]] )
			@throw [NSException exceptionWithName:NSInvalidArgumentException reason:[NSString stringWithFormat:@"An attempt was made to add and object of class $@ to a NDTrie", [theString class]] userInfo:nil];
		count += setObjectForKey( [self root], theString, theString, keyComponentForString );
	}
#else
	for( NSUInteger i = 0, c = [anArray count]; i < c; i++ )
	{
		NSString	* theString = [anArray objectAtIndex:i];
		if( ![theString isKindOfClass:[NSString class]] )
			@throw [NSException exceptionWithName:NSInvalidArgumentException reason:[NSString stringWithFormat:@"An attempt was made to add and object of class $@ to a NDTrie", [theString class]] userInfo:nil];
		count += setObjectForKey( [self root], theString, theString );
	}
#endif
}

- (void)addDictionay:(NSDictionary *)aDictionary
{
	NSArray		* theKeysArray = [aDictionary allKeys];
#if __OBJC2__
	for( NSString * theKey in theKeysArray )
	{
		if( ![theKey isKindOfClass:[NSString class]] )
			@throw [NSException exceptionWithName:NSInvalidArgumentException reason:[NSString stringWithFormat:@"An attempt was made to add and object of class $@ to a NDTrie", [theKey class]] userInfo:nil];
		count += setObjectForKey( [self root], [aDictionary objectForKey:theKey], theKey, keyComponentForString );
	}
#else
	for( NSUInteger i = 0, c = [theKeysArray count]; i < c; i++ )
	{
		NSString	* theKey = [theKeysArray objectAtIndex:i];
		if( ![theKey isKindOfClass:[NSString class]] )
			@throw [NSException exceptionWithName:NSInvalidArgumentException reason:[NSString stringWithFormat:@"An attempt was made to add and object of class $@ to a NDTrie", [theKey class]] userInfo:nil];
		count += setObjectForKey( [self root], [aDictionary objectForKey:theKey], theKey );
	}
#endif
}
	 
- (void)removeObjectForKey:(NSString *)aString
{
	BOOL	theFoundNode = NO;
	removeObjectForKey( [self root], aString, 0, &theFoundNode, keyComponentForString );	
	if( theFoundNode )
		count--;
}

- (void)removeAllObjects
{
	removeAllChildren( [self root] );
	count = 0;
}

- (void)removeAllObjectsForKeysWithPrefix:(NSString *)aPrefix
{
	if( aPrefix != nil && [aPrefix length] > 0 )
	{
		NSUInteger			thePosition = 0;
		struct trieNode		* theParent = nil,
							* theNode = findNode( [self root], aPrefix, 0, NO, &theParent, &thePosition, keyComponentForString );

		if( theNode != NULL && theParent != NULL )
			count -= removeChild( [self root], aPrefix, keyComponentForString );
	}
	else
		removeAllChildren( [self root] );
}

@end

@implementation NDTrie (Private)
- (struct trieNode*)root
{
	return (struct trieNode*)root;
}
@end

static struct trieNode * _createNode( NSUInteger aKey )
{
	struct trieNode		* theNode = malloc( sizeof(struct trieNode) );
	theNode->key = aKey;
	theNode->children = NULL;
	theNode->object = nil;
	theNode->count = 0;
	return theNode;
}

NSUInteger removeAllChildren( struct trieNode * aNode )
{
	NSUInteger	theCount = 0;

	if( aNode->children )
	{
		for( NSUInteger i = 0; i < aNode->count; i++ )
		{
			theCount += removeAllChildren( aNode->children[i] );
			[aNode->children[i]->object release];
			free( aNode->children[i] );
		}

		free( aNode->children );
		aNode->children = NULL;
		aNode->count = 0;
		aNode->size = 0;
	}

	if( aNode->object != nil )
		theCount++;

	return theCount;
}

/*
	Perform binary search to find node for key or location to insert node
 */
inline static NSUInteger _indexForChild( struct trieNode * aNode, NSUInteger aKey )
{
	NSUInteger		theIndex = NSNotFound;
	if( aNode->count > 0 )
	{
		NSUInteger		l = 0,
						u = aNode->count,
						m;

		while( l < u-1 && theIndex == NSNotFound )
		{
			m = (u+l) >> 1;
			if( aNode->children[m]->key < aKey )
				l = m;
			else if( aNode->children[m]->key > aKey )
				u = m;
			else
				theIndex = m;
		}
		if( theIndex == NSNotFound )
			theIndex = aNode->children[l]->key < aKey ? u : l;
	}
	else
		theIndex = 0;
	return theIndex;
}

/*
	Finds a node, if aCreate == YES nodes are created as needed but the final node is not set to terminal node
	Should not return NULL if aCreate == YES
 */
static struct trieNode * findNode( struct trieNode * aNode, id aKey, NSUInteger anIndex, BOOL aCreate, struct trieNode ** aParent, NSUInteger * anPosition, NSUInteger (*aKeyComponentFunc)( id, NSUInteger, BOOL * ) )
{
	struct trieNode		* theNode = NULL;
	BOOL				theEnd = NO;
	NSUInteger			theKeyComponent = aKeyComponentFunc( aKey, anIndex, &theEnd );

	if( !theEnd )
	{
		if( aNode->children != NULL )
		{
			NSUInteger		theIndex = _indexForChild( aNode, theKeyComponent );
			if( theIndex >= aNode->count || aNode->children[theIndex]->key != theKeyComponent )
			{
				if( aCreate )
				{
					if( aNode->count >= aNode->size )
					{
						aNode->size <<= 1;
						aNode->children = realloc( aNode->children, aNode->size*sizeof(struct trieNode) );
						NSCParameterAssert( aNode->children != NULL );
					}
					memmove( &aNode->children[theIndex+1], &aNode->children[theIndex], (aNode->count-theIndex)*sizeof(struct trieNode*) );
					aNode->children[theIndex] = _createNode( theKeyComponent );
					theNode = aNode->children[theIndex];
					aNode->count++;
					if( anPosition )
						*anPosition = theIndex;
					if( aParent )
						*aParent = aNode;
					
				}
			}
			else
			{			
				theNode = aNode->children[theIndex];
				if( anPosition )
					*anPosition = theIndex;
				if( aParent )
					*aParent = aNode;
			}
		}
		else if( aCreate )
		{
			aNode->size = 4;
			aNode->children = malloc( aNode->size*sizeof(struct trieNode) );
			aNode->children[0] = _createNode( theKeyComponent );
			theNode = aNode->children[0];
			aNode->count++;
			if( anPosition )
				*anPosition = 0;
			if( aParent )
				*aParent = aNode;
		}

		anIndex++;
		if( theNode != NULL )
			theNode = findNode( theNode, aKey, anIndex, aCreate, aParent, anPosition, aKeyComponentFunc );
	}
	else
		theNode = aNode;

	return theNode;
}

BOOL removeObjectForKey( struct trieNode * aNode, id aKey, NSUInteger anIndex, BOOL * aFoundNode, NSUInteger (*aKeyComponentFunc)( id, NSUInteger, BOOL * ) )
{
	BOOL			theResult = NO;
	BOOL			theEnd = NO;
	NSUInteger		theKeyComponent = aKeyComponentFunc( aKey, anIndex, &theEnd );
	if( aNode->children == NULL )
	{
		if( theEnd )
		{
			*aFoundNode = aNode->object != nil;
			theResult = YES;
		}
	}
	else if( !theEnd )
	{
		NSUInteger		theIndex = _indexForChild( aNode, theKeyComponent );
		if( theIndex < aNode->count )
		{
			if( aNode->children[theIndex]->key == theKeyComponent )
			{
				if( removeObjectForKey( aNode->children[theIndex], aKey, anIndex+1, aFoundNode, keyComponentForString ) )
				{
					aNode->count--;
					[aNode->children[theIndex]->object release];
					free( aNode->children[theIndex] );
					if( aNode->count > 0 )
						memmove( &aNode->children[theIndex], &aNode->children[theIndex+1], (aNode->count-theIndex)*sizeof(struct trieNode*) );
					else
					{
						free( aNode->children );
						aNode->children = NULL;
						theResult = YES;
					}
				}
			}
		}
	}
	return theResult;
}

NSUInteger removeChild( struct trieNode * aRoot, id aPrefix, NSUInteger (*aKeyComponentFunc)( id, NSUInteger, BOOL* ) )
{
	NSUInteger		theRemoveCount = 0;
	NSCParameterAssert( aPrefix != nil );

	NSUInteger			thePosition = 0;
	struct trieNode		* theParent = nil,
						* theNode = findNode( aRoot, aPrefix, 0, NO, &theParent, &thePosition, aKeyComponentFunc );

	NSCParameterAssert( theParent != theNode );
	
	if( theNode != NULL && theParent != NULL )
	{
		theRemoveCount = removeAllChildren( theNode );
#ifndef __OBJC_GC__
		[theNode->object release];
#else
		CFRelease(theNode->object);
#endif
		free( theNode );
		memmove( &theParent->children[thePosition], &theParent->children[thePosition+1], (theParent->count-thePosition)*sizeof(struct trieNode*) );
		theParent->count--;
	}
	return theRemoveCount;
}

BOOL setObjectForKey( struct trieNode * aNode, id anObject, id aKey, NSUInteger (*aKeyComponentFunc)( id, NSUInteger, BOOL * ) )
{
	BOOL				theNewString = NO;
	struct trieNode		* theNode = findNode( aNode, aKey, 0, YES, NULL, NULL, aKeyComponentFunc );
	NSCParameterAssert( theNode != NULL );

	theNewString = theNode->object == nil;
#ifdef __OBJC_GC__
	CFRelease(theNode->object);
	theNode->object = CFRetain(anObject);
#else
	[theNode->object release];
	theNode->object = [anObject retain];
#endif
	return theNewString;
}

/*
	forEveryObjectFromNode uses malloc instead of a variable-length automatic array,
	so that the string would not have to be repeatedly reconsructed and because an automatic array would take up alot more stack space
 */
static BOOL _recusiveForEveryObject( struct trieNode *, BOOL(*)(id,void*), void * );
void forEveryObjectFromNode( struct trieNode * aNode, BOOL(*aFunc)(id,void*), void * aContext )
{
	BOOL		theContinue = YES;

	if( aNode->object != nil )
		theContinue = aFunc( aNode->object, aContext );

	for( NSUInteger i = 0; i < aNode->count && theContinue; i++ )
		theContinue = _recusiveForEveryObject( aNode->children[i], aFunc, aContext );
}

BOOL _recusiveForEveryObject( struct trieNode * aNode, BOOL(*aFunc)(id,void*), void * aContext )
{
	BOOL		theContinue = YES;

	if( aNode->object != nil )
		theContinue = aFunc( aNode->object, aContext );

	for( NSUInteger i = 0; i < aNode->count && theContinue; i++ )
		theContinue = _recusiveForEveryObject( aNode->children[i], aFunc, aContext );
	return theContinue;
}

BOOL nodesAreEqual( struct trieNode * aNodeA, struct trieNode * aNodeB )
{
	BOOL		theEqual = YES;

	// need to test for two equal object pointers because, the root node they will both be nil
	if( aNodeA->count == aNodeB->count && aNodeA->key == aNodeB->key && (aNodeA->object == aNodeB->object || [aNodeA->object isEqual:aNodeB->object]) )
	{
		for( NSUInteger i = 0; i < aNodeA->count && theEqual; i++ )
			theEqual = nodesAreEqual( aNodeA->children[i], aNodeB->children[i] );
	}
	else
		theEqual = NO;
	return theEqual;
}

static struct trieNode * copyNode( struct trieNode * aNode )
{
	struct trieNode		* theNode = _createNode(aNode->key);
#ifdef __OBJC_GC__
	theNode->object = CFRetain(aNode->object);
#else
	theNode->object = [aNode->object retain];
#endif
	theNode->count = theNode->size = aNode->count;
	theNode->children = (struct trieNode**)malloc( theNode->size * sizeof(struct trieNode) );
	for( NSUInteger i = 0; i < theNode->count; i++ )
		theNode->children[i] = copyNode( aNode->children[i] );
	return theNode;
}
