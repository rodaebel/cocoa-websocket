//
//  WebSocketTests.h
//  WebSocketTests
//
//  Created by Tobias on 6/18/11.
//

#import <SenTestingKit/SenTestingKit.h>
#import "WebSocket.h"


@interface WebSocketTests : SenTestCase <WebSocketDelegate> {
@private
    WebSocket *webSocket;
}

@end
