//
//  WebSocket.m
//  Zimt
//
//  Created by Esad Hajdarevic on 2/14/10.
//  Copyright 2010 OpenResearch Software Development OG. All rights reserved.
//

#import "WebSocket.h"
#import "AsyncSocket.h"


NSString* const WebSocketErrorDomain = @"WebSocketErrorDomain";
NSString* const WebSocketException = @"WebSocketException";

enum {
    WebSocketTagHandshake = 0,
    WebSocketTagMessage = 1
};

#define HANDSHAKE_REQUEST @"GET %@ HTTP/1.1\r\n" \
                           "Upgrade: WebSocket\r\n" \
                           "Connection: Upgrade\r\n" \
                           "Sec-WebSocket-Protocol: sample\r\n" \
                           "Sec-WebSocket-Key1: %@\r\n" \
                           "Sec-WebSocket-Key2: %@\r\n" \
                           "Host: %@\r\n" \
                           "Origin: %@\r\n" \
                           "\r\n%@"


@implementation WebSocket

@synthesize delegate, url, origin, connected, runLoopModes;

#pragma mark Initializers

+ (id)webSocketWithURLString:(NSString*)urlString delegate:(id<WebSocketDelegate>)aDelegate {
    return [[[WebSocket alloc] initWithURLString:urlString delegate:aDelegate] autorelease];
}

-(id)initWithURLString:(NSString *)urlString delegate:(id<WebSocketDelegate>)aDelegate {
    self = [super init];
    if (self) {
        self.delegate = aDelegate;
        url = [[NSURL URLWithString:urlString] retain];
        if (![url.scheme isEqualToString:@"ws"]) {
            [NSException raise:WebSocketException format:@"Unsupported protocol %@", url.scheme];
        }
        socket = [[AsyncSocket alloc] initWithDelegate:self];
        self.runLoopModes = [NSArray arrayWithObjects:NSRunLoopCommonModes, nil];
    }
    return self;
}

#pragma mark Delegate dispatch methods

-(void)_dispatchFailure:(NSNumber*)code {
    if(delegate && [delegate respondsToSelector:@selector(webSocket:didFailWithError:)]) {
        [delegate webSocket:self didFailWithError:[NSError errorWithDomain:WebSocketErrorDomain code:[code intValue] userInfo:nil]];
    }
}

-(void)_dispatchClosed {
    if (delegate && [delegate respondsToSelector:@selector(webSocketDidClose:)]) {
        [delegate webSocketDidClose:self];
    }
}

-(void)_dispatchOpened {
    if (delegate && [delegate respondsToSelector:@selector(webSocketDidOpen:)]) {
        [delegate webSocketDidOpen:self];
    }
}

-(void)_dispatchMessageReceived:(NSString*)message {
    if (delegate && [delegate respondsToSelector:@selector(webSocket:didReceiveMessage:)]) {
        [delegate webSocket:self didReceiveMessage:message];
    }
}

-(void)_dispatchMessageSent {
    if (delegate && [delegate respondsToSelector:@selector(webSocketDidSendMessage:)]) {
        [delegate webSocketDidSendMessage:self];
    }
}

#pragma mark Private

-(void)_readNextMessage {
    [socket readDataToData:[NSData dataWithBytes:"\xFF" length:1] withTimeout:-1 tag:WebSocketTagMessage];
}

-(NSString *)_makeKey {
    uint32_t spaces;
    uint32_t num, prod;
    NSInteger keylen;
    unichar letter;

    spaces = (arc4random() % 12) + 1;
    num = arc4random() % (4294967295U / spaces);
    prod = spaces * num;

    NSMutableString *key = [NSMutableString stringWithFormat:@"%ld", prod];

    keylen = [key length];

    for (NSInteger i=0; i<keylen; i++) {

        if ((arc4random() % 2) == 0)
            letter = (arc4random() % (64 - 33 + 1)) + 33;
        else
            letter = (arc4random() % (126 - 58 + 1)) + 58;

        [key insertString:[[[NSString alloc] initWithCharacters:&letter length:1] autorelease] atIndex:(arc4random() % (keylen-1))];
    }

    keylen = [key length];

    for (uint32_t i=0; i<spaces; i++)
        [key insertString:@" " atIndex:((arc4random() % (keylen-2))+1)];

    return key;
}

#pragma mark Public interface

-(void)close {
    [socket disconnectAfterReadingAndWriting];
}

-(void)open {
    if (!connected) {
        [socket connectToHost:url.host onPort:[url.port intValue] withTimeout:5 error:nil];
        if (runLoopModes) [socket setRunLoopModes:runLoopModes];
    }
}

-(void)send:(NSString*)message {
    NSMutableData* data = [NSMutableData data];
    [data appendBytes:"\x00" length:1];
    [data appendData:[message dataUsingEncoding:NSUTF8StringEncoding]];
    [data appendBytes:"\xFF" length:1];
    [socket writeData:data withTimeout:-1 tag:WebSocketTagMessage];
}

#pragma mark AsyncSocket delegate methods

-(void)onSocketDidDisconnect:(AsyncSocket *)sock {
    connected = NO;
}

-(void)onSocket:(AsyncSocket *)sock willDisconnectWithError:(NSError *)err {
    if (!connected) {
        [self _dispatchFailure:[NSNumber numberWithInt:WebSocketErrorConnectionFailed]];
    } else {
        [self _dispatchClosed];
    }
}

- (void)onSocket:(AsyncSocket *)sock didConnectToHost:(NSString *)host port:(UInt16)port {

    NSString *requestOrigin = (self.origin) ? self.origin : [NSString stringWithFormat:@"http://%@", url.host];

    NSString *requestPath = (url.query) ? [NSString stringWithFormat:@"%@?%@", url.path, url.query] : url.path;

    NSString *key1 = [self _makeKey];
    NSString *key2 = [self _makeKey];
    NSMutableString *key3 = [NSMutableString string];

    for (int i=0; i<8; i++) {
        unichar letter = arc4random() % 126;
        [key3 appendString:[[[NSString alloc] initWithCharacters:&letter length:1] autorelease]];
    }

    NSString *request = [NSString stringWithFormat:HANDSHAKE_REQUEST,
                                                   requestPath,
                                                   key1,
                                                   key2,
                                                   url.host,
                                                   requestOrigin,
                                                   key3];

    [socket writeData:[request dataUsingEncoding:NSASCIIStringEncoding] withTimeout:-1 tag:WebSocketTagHandshake];
}

-(void)onSocket:(AsyncSocket *)sock didWriteDataWithTag:(long)tag {
    if (tag == WebSocketTagHandshake) {
        [sock readDataWithTimeout:-1 tag:WebSocketTagHandshake];
    } else if (tag == WebSocketTagMessage) {
        [self _dispatchMessageSent];
    }
}

-(void)onSocket:(AsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag {

    if (tag == WebSocketTagHandshake) {

        NSString *upgrade;
        NSString *connection;
        NSData *body;
        UInt32 statusCode;

        CFHTTPMessageRef message = CFHTTPMessageCreateEmpty(kCFAllocatorDefault, FALSE);

        if (!CFHTTPMessageAppendBytes(message, [data bytes], [data length])) {
            [self _dispatchFailure:[NSNumber numberWithInt:WebSocketErrorHandshakeFailed]];
        }

        if (CFHTTPMessageIsHeaderComplete(message)) {
            upgrade = [(NSString *) CFHTTPMessageCopyHeaderFieldValue(message, CFSTR("Upgrade")) autorelease];
            connection = [(NSString *) CFHTTPMessageCopyHeaderFieldValue(message, CFSTR("Connection")) autorelease];
            statusCode = CFHTTPMessageGetResponseStatusCode(message);
        }

        if (statusCode == 101 && [upgrade isEqualToString:@"WebSocket"] && [connection isEqualToString:@"Upgrade"]) {

            body = [(NSData *)CFHTTPMessageCopyBody(message) autorelease];

            connected = YES;

            [self _dispatchOpened];
            [self _readNextMessage];
        } else {
            [self _dispatchFailure:[NSNumber numberWithInt:WebSocketErrorHandshakeFailed]];
        }

    } else if (tag == WebSocketTagMessage) {
        char firstByte = 0xFF;
        [data getBytes:&firstByte length:1];
        if (firstByte != 0x00) return; // Discard message
        NSString *message = [[[NSString alloc] initWithData:[data subdataWithRange:NSMakeRange(1, [data length]-2)] encoding:NSUTF8StringEncoding] autorelease];

        [self _dispatchMessageReceived:message];
        [self _readNextMessage];
    }
}

#pragma mark Destructor

-(void)dealloc {
    socket.delegate = nil;
    [socket disconnect];
    [socket release];
    [runLoopModes release];
    [url release];
    [super dealloc];
}

@end
