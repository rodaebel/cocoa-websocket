//
//  WebSocketTests.m
//  WebSocketTests
//
//  Created by Tobias on 6/18/11.
//

#import "WebSocketTests.h"


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

# pragma mark - WebSocketDelegate Methods

- (void)webSocketDidOpen:(WebSocket *)ws {

}

@end
