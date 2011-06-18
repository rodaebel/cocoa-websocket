//
//  WebSocketTests.m
//  WebSocketTests
//
//  Created by Tobias on 6/18/11.
//

#import "WebSocketTests.h"


@implementation WebSocketTests

- (void)testWebSocket
{
    WebSocket *ws = [WebSocket webSocketWithURLString:@"ws://localhost:8888/" delegate:self];

    STAssertNotNil(ws, @"Something prevents our Web Socket instance from being created");
    STAssertFalse(ws.connected, @"Web Socket already connected");
}

- (void)testWebSocketWrongProtocol
{
    STAssertThrows([WebSocket webSocketWithURLString:@"http://localhost:8888/" delegate:self],
                   @"Should throw an exception");
}

# pragma mark - WebSocketDelegate Methods

- (void)webSocketDidOpen:(WebSocket *)ws {

}

@end
