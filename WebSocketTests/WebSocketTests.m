//
//  WebSocketTests.m
//  WebSocketTests
//
//  Created by Tobias on 6/18/11.
//

#import "WebSocketTests.h"


typedef struct SecKey {
    uint32_t num;
    NSString *key;
} SecKey;


@interface WebSocket (TestAdditions)

- (struct SecKey)_makeKey;
- (void)_makeChallengeNumber:(uint32_t)number withBuffer:(unsigned char *)buf;

@end


@implementation WebSocketTests

- (void)setUp
{
    webSocket = [WebSocket webSocketWithURLString:@"ws://localhost:8888/" delegate:self];
}

- (void)tearDown
{
    webSocket = nil;
}

- (void)testWebSocket
{
    STAssertNotNil(webSocket, @"Something prevents our Web Socket instance from being created.");
    STAssertTrue([webSocket isKindOfClass:[WebSocket class]], @"Cannot find the Web Socket instance.");
    STAssertFalse(webSocket.connected, @"Web Socket already connected.");
}

- (void)testWebSocketWrongProtocol
{
    STAssertThrows([WebSocket webSocketWithURLString:@"http://localhost:8888/" delegate:self],
                   @"Should throw an exception.");
}

- (void)testWebSocketKeyGeneration
{
    SecKey seckey;
    NSString *key;
    unsigned char bytes[4];

    seckey = [webSocket _makeKey];

    key = seckey.key;

    STAssertTrue([key isKindOfClass:[NSString class]],
                 @"Security Key must be a string");
    STAssertTrue([key characterAtIndex:0] != 13U,
                 @"First character must not be blank");
    STAssertTrue([key characterAtIndex:[key length]-1] != 13U,
                 @"Last character must not be blank");

    [webSocket _makeChallengeNumber:seckey.num withBuffer:&bytes[0]];
}

# pragma mark - WebSocketDelegate Methods

- (void)webSocketDidOpen:(WebSocket *)ws {

}

@end
