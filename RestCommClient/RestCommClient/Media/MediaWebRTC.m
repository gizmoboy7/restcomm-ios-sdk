/*
 * libjingle
 * Copyright 2014 Google Inc.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *
 *  1. Redistributions of source code must retain the above copyright notice,
 *     this list of conditions and the following disclaimer.
 *  2. Redistributions in binary form must reproduce the above copyright notice,
 *     this list of conditions and the following disclaimer in the documentation
 *     and/or other materials provided with the distribution.
 *  3. The name of the author may not be used to endorse or promote products
 *     derived from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR IMPLIED
 * WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO
 * EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 * SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
 * PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS;
 * OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
 * WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR
 * OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
 * ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

/*
 * TeleStax, Open Source Cloud Communications
 * Copyright 2011-2015, Telestax Inc and individual contributors
 * by the @authors tag.
 *
 * This program is free software: you can redistribute it and/or modify
 * under the terms of the GNU Affero General Public License as
 * published by the Free Software Foundation; either version 3 of
 * the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Affero General Public License for more details.
 *
 * You should have received a copy of the GNU Affero General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>
 *
 * For questions related to commercial use licensing, please contact sales@telestax.com.
 *
 */

#import "ARDAppClient+Internal.h"
#import "MediaWebRTC.h"

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

#import "RTCICECandidate.h"
#import "RTCPeerConnection.h"
#import "RTCICEServer.h"
#import "RTCMediaConstraints.h"
#import "RTCMediaStream.h"
#import "RTCPair.h"
#import "RTCVideoCapturer.h"
#import "RTCVideoTrack.h"
#import "RTCSessionDescription.h"
#import "RestCommClient.h"

#import "common.h"
#import "Utilities.h"

@implementation MediaWebRTC

// TODO: update these properly
static NSString *kARDTurnRequestUrl =
    @"https://computeengineondemand.appspot.com"
    @"/turn?username=iapprtc&key=4080218913";
static NSString *kARDDefaultSTUNServerUrl =
    @"stun:stun.l.google.com:19302";

static NSString *kARDAppClientErrorDomain = @"ARDAppClient";
//static NSInteger kARDAppClientErrorUnknown = -1;
//static NSInteger kARDAppClientErrorRoomFull = -2;
//static NSInteger kARDAppClientErrorCreateSDP = -3;
//static NSInteger kARDAppClientErrorSetSDP = -4;
//static NSInteger kARDAppClientErrorInvalidClient = -5;
//static NSInteger kARDAppClientErrorInvalidRoom = -6;

- (id)initWithDelegate:(id<MediaDelegate>)mediaDelegate
{
    RCLogNotice("[MediaWebRTC initWithDelegate]");
    self = [super init];
    if (self) {
        self.mediaDelegate = mediaDelegate;
        _isTurnComplete = NO;
        // for now we are always iniator
        _isInitiator = YES;
        self.sofia_handle = nil;
        self.videoAllowed = NO;
    }
    return self;
}

- (void)dealloc {
    RCLogNotice("[MediaWebRTC dealloc]");
    //[self disconnect];
}

// entry point for WebRTC handling
// sofia handle is used for outgoing calls; nil in incoming
// sdp is used for incoming calls; nil in outgoing
- (void)connect:(NSString*)sofia_handle sdp:(NSString*)sdp isInitiator:(BOOL)initiator withVideo:(BOOL)videoAllowed
{
    RCLogNotice("[MediaWebRTC connect: %s \nsdp:%s \nisInitiator:%s \nwithVideo:%s]",
                [sofia_handle UTF8String],
                [sdp UTF8String],
                (initiator) ? "true" : "false",
                (videoAllowed) ? "true" : "false");
    if (!initiator) {
        _isInitiator = NO;
    }
    else {
        _isInitiator = YES;
    }
    self.videoAllowed = videoAllowed;
    if (sofia_handle) {
        self.sofia_handle = sofia_handle;
    }
    
    // in AppRTCDemo this happens in constructor
    NSURL *turnRequestURL = [NSURL URLWithString:kARDTurnRequestUrl];
    _turnClient = [[ARDCEODTURNClient alloc] initWithURL:turnRequestURL];
    [self configure];
    
    // in AppRTCDemo, connectToRoom
    // Request TURN
    // TODO: uncomment this when we are ready to re-introduce TURN
    __weak MediaWebRTC *weakSelf = self;
    /*
    [_turnClient requestServersWithCompletionHandler:^(NSArray *turnServers,
                                                       NSError *error) {
        if (error) {
            NSLog(@"Error retrieving TURN servers: %@", error);
        }
        MediaWebRTC *strongSelf = weakSelf;
        [strongSelf.iceServers addObjectsFromArray:turnServers];
        strongSelf.isTurnComplete = YES;
        [strongSelf startSignalingIfReady:sdp];
    }];
     */
    
    // TODO: remove this when we are ready to re-introduce TURN
    self.isTurnComplete = YES;
    [self startSignalingIfReady:sdp];
}

- (void)disconnect {
    RCLogNotice("[MediaWebRTC disconnect]");
    if (_state == kARDAppClientStateDisconnected) {
        return;
    }
    
    _state = kARDAppClientStateDisconnected;

    /*
    if (self.hasJoinedRoomServerRoom) {
        [_roomServerClient leaveRoomWithRoomId:_roomId
                                      clientId:_clientId
                             completionHandler:nil];
    }
    
    if (_channel) {
        if (_channel.state == kARDSignalingChannelStateRegistered) {
            // Tell the other client we're hanging up.
            ARDByeMessage *byeMessage = [[ARDByeMessage alloc] init];
            [_channel sendMessage:byeMessage];
        }
        // Disconnect from collider.
        _channel = nil;
    }
    _clientId = nil;
    _roomId = nil;
     */
    _isInitiator = NO;
    //_hasReceivedSdp = NO;
    //_messageQueue = [NSMutableArray array];
    [_peerConnection close];
    _peerConnection = nil;
    RCLogNotice("[MediaWebRTC disconnect] end");
}


- (void) terminate
{
    RCLogNotice("[MediaWebRTC terminate]");
    //[RTCPeerConnectionFactory deinitializeSSL];
}

- (void)configure {
    _factory = [[RTCPeerConnectionFactory alloc] init];
    //_messageQueue = [NSMutableArray array]; 
    _iceCandidates = [NSMutableArray array];
    _iceServers = [NSMutableArray arrayWithObject:[self defaultSTUNServer]];
}

- (RTCICEServer *)defaultSTUNServer {
    NSURL *defaultSTUNServerURL = [NSURL URLWithString:kARDDefaultSTUNServerUrl];
    return [[RTCICEServer alloc] initWithURI:defaultSTUNServerURL
                                    username:@""
                                    password:@""];
}

- (void)startSignalingIfReady:(NSString*)sdp {
    if (!_isTurnComplete) {
        return;
    }
    _state = kARDAppClientStateConnected;
    
    // Create peer connection
    RTCMediaConstraints *constraints = [self defaultPeerConnectionConstraints];
    _peerConnection = [_factory peerConnectionWithICEServers:_iceServers
                                                 constraints:constraints
                                                    delegate:self];
    RTCMediaStream *localStream = [self createLocalMediaStream];
    [_peerConnection addStream:localStream];
    if (_isInitiator) {
        [self sendOffer];
    } else {
        [self processSignalingMessage:[sdp UTF8String] type:kARDSignalingMessageTypeOffer];
    }
}

- (RTCMediaConstraints *)defaultPeerConnectionConstraints {
    NSArray *optionalConstraints = @[[[RTCPair alloc] initWithKey:@"DtlsSrtpKeyAgreement" value:@"true"]];
    RTCMediaConstraints* constraints = [[RTCMediaConstraints alloc] initWithMandatoryConstraints:nil
                                                                             optionalConstraints:optionalConstraints];
    return constraints;
}

- (void)sendOffer {
    [_peerConnection createOfferWithDelegate:self
                                 constraints:[self defaultOfferConstraints]];
}

// Offer/Answer Constraints
- (RTCMediaConstraints *)defaultOfferConstraints {
    NSString * video = @"false";
    if (self.videoAllowed) {
        video = @"true";
    }
    NSArray *mandatoryConstraints = @[[[RTCPair alloc] initWithKey:@"OfferToReceiveAudio" value:@"true"],
                                      [[RTCPair alloc] initWithKey:@"OfferToReceiveVideo" value:video]];
    RTCMediaConstraints* constraints =
    [[RTCMediaConstraints alloc] initWithMandatoryConstraints:mandatoryConstraints
                                          optionalConstraints:nil];
    return constraints;
}

- (RTCMediaConstraints *)defaultAnswerConstraints {
    return [self defaultOfferConstraints];
}

- (RTCMediaStream *)createLocalMediaStream
{
    RCLogNotice("[MediaWebRTC createLocalMediaStream]");

    RTCMediaStream* localStream = [_factory mediaStreamWithLabel:@"ARDAMS"];

    if (self.videoAllowed) {
        RTCVideoTrack* localVideoTrack = nil;
        
        // The iOS simulator doesn't provide any sort of camera capture
        // support or emulation (http://goo.gl/rHAnC1) so don't bother
        // trying to open a local stream.
        // TODO(tkchin): local video capture for OSX. See
        // https://code.google.com/p/webrtc/issues/detail?id=3417.
#if !TARGET_IPHONE_SIMULATOR && TARGET_OS_IPHONE
        NSString *cameraID = nil;
        for (AVCaptureDevice *captureDevice in
             [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo]) {
            if (captureDevice.position == AVCaptureDevicePositionFront) {
                cameraID = [captureDevice localizedName];
                break;
            }
        }
        NSAssert(cameraID, @"Unable to get the front camera id");
        
        RTCVideoCapturer *capturer =
        [RTCVideoCapturer capturerWithDeviceName:cameraID];
        RTCMediaConstraints *mediaConstraints = [[RTCMediaConstraints alloc] initWithMandatoryConstraints:nil
                                                                                      optionalConstraints:nil];
        RTCVideoSource *videoSource =
        [_factory videoSourceWithCapturer:capturer
                              constraints:mediaConstraints];
        localVideoTrack =
        [_factory videoTrackWithID:@"ARDAMSv0" source:videoSource];
        if (localVideoTrack) {
            [localStream addVideoTrack:localVideoTrack];
        }
        
        [self.mediaDelegate mediaController:self didReceiveLocalVideoTrack:localVideoTrack];
#endif
    }
    [localStream addAudioTrack:[_factory audioTrackWithID:@"ARDAMSa0"]];
    
    return localStream;
}

- (void)mute
{
    if (_peerConnection.localStreams) {
        for (int i = 0; i < [_peerConnection.localStreams count]; i++) {
            for (int j = 0; j < [[[_peerConnection.localStreams objectAtIndex:i] audioTracks] count]; j++) {
                RTCMediaStreamTrack * track = [[[_peerConnection.localStreams objectAtIndex:i] audioTracks] objectAtIndex:j];
                [track setEnabled:NO];
            }
        }
    }
}

- (void)unmute
{
    if (_peerConnection.localStreams) {
        for (int i = 0; i < [_peerConnection.localStreams count]; i++) {
            for (int j = 0; j < [[[_peerConnection.localStreams objectAtIndex:i] audioTracks] count]; j++) {
                RTCMediaStreamTrack * track = [[[_peerConnection.localStreams objectAtIndex:i] audioTracks] objectAtIndex:j];
                [track setEnabled:YES];
            }
        }
    }
}

- (void)muteVideo
{
    if (_peerConnection.localStreams) {
        for (int i = 0; i < [_peerConnection.localStreams count]; i++) {
            for (int j = 0; j < [[[_peerConnection.localStreams objectAtIndex:i] videoTracks] count]; j++) {
                RTCMediaStreamTrack * track = [[[_peerConnection.localStreams objectAtIndex:i] videoTracks] objectAtIndex:j];
                [track setEnabled:NO];
            }
        }
    }
}

- (void)unmuteVideo
{
    if (_peerConnection.localStreams) {
        for (int i = 0; i < [_peerConnection.localStreams count]; i++) {
            for (int j = 0; j < [[[_peerConnection.localStreams objectAtIndex:i] videoTracks] count]; j++) {
                RTCMediaStreamTrack * track = [[[_peerConnection.localStreams objectAtIndex:i] videoTracks] objectAtIndex:j];
                [track setEnabled:YES];
            }
        }
    }
}

#pragma mark - Helpers
// from candidateless sdp stored at self.sdp and candidates stored at array, we construct a full sdp
- (NSString*)outgoingUpdateSdpWithCandidates:(NSArray *)array
{
    // split audio & video candidates in 2 groups of strings
    NSMutableString * audioCandidates = [[NSMutableString alloc] init];
    NSMutableString * videoCandidates = [[NSMutableString alloc] init];
    BOOL isVideo = NO;
    for (int i = 0; i < _iceCandidates.count; i++) {
        RTCICECandidate *iceCandidate = (RTCICECandidate*)[_iceCandidates objectAtIndex:i];
        if ([iceCandidate.sdpMid isEqualToString:@"audio"]) {
            // don't forget to prepend an 'a=' to make this an attribute line and to append '\r\n'
            [audioCandidates appendFormat:@"a=%@\r\n",iceCandidate.sdp];
        }
        if ([iceCandidate.sdpMid isEqualToString:@"video"]) {
            // don't forget to prepend an 'a=' to make this an attribute line and to append '\r\n'
            [videoCandidates appendFormat:@"a=%@\r\n",iceCandidate.sdp];
            isVideo = YES;
        }
    }
    
    // insert inside the candidateless SDP the candidates per media type
    NSMutableString *searchedString = [self.sdp mutableCopy];
    NSRange searchedRange = NSMakeRange(0, [searchedString length]);
    NSString *pattern = @"a=rtcp:.*?\\r\\n";
    NSError  *error = nil;
    
    NSRegularExpression* regex = [NSRegularExpression regularExpressionWithPattern:pattern
                                                                           options:NSRegularExpressionDotMatchesLineSeparators
                                                                             error:&error];
    if (error != nil) {
        NSLog(@"outgoingUpdateSdpWithCandidates: regex error");
        return @"";
    }
    
    NSTextCheckingResult* match = [regex firstMatchInString:searchedString options:0 range:searchedRange];
    int matchIndex = 0;
    if (matchIndex == 0) {
        [regex replaceMatchesInString:searchedString options:0 range:[match range] withTemplate:[NSString stringWithFormat:@"%@%@",
                                                                                                             @"$0",audioCandidates]];
    }
    
    // search again since the searchedString has been altered
    NSArray* matches = [regex matchesInString:searchedString options:0 range:searchedRange];
    if ([matches count] == 2) {
        // count of 2 means we also have video. If we don't we shouldn't do anything
        NSTextCheckingResult* match = [matches objectAtIndex:1];
        [regex replaceMatchesInString:searchedString options:0 range:[match range] withTemplate:[NSString stringWithFormat:@"%@%@",
                                                                                                 @"$0", videoCandidates]];
    }
    
    // important: the complete message also has the sofia handle (so that sofia knows which active session to associate this with)
    NSString * completeMessage = [NSString stringWithFormat:@"%@", searchedString];

    return completeMessage;
}

// remove candidate lines from the given sdp and return them as elements of an NSArray
-(NSDictionary*)incomingFilterCandidatesFromSdp:(NSMutableString*)sdp
{
    NSMutableArray * audioCandidates = [[NSMutableArray alloc] init];
    NSMutableArray * videoCandidates = [[NSMutableArray alloc] init];
    
    NSString *searchedString = sdp;
    NSRange searchedRange = NSMakeRange(0, [searchedString length]);
    NSString *pattern = @"m=audio|m=video|a=(candidate.*)\\r\\n";
    NSError  *error = nil;
    
    NSString * collectionState = @"none";
    NSRegularExpression* regex = [NSRegularExpression regularExpressionWithPattern: pattern options:0 error:&error];
    NSArray* matches = [regex matchesInString:searchedString options:0 range: searchedRange];
    for (NSTextCheckingResult* match in matches) {
        //NSString* matchText = [searchedString substringWithRange:[match range]];
        NSString * stringMatch = [searchedString substringWithRange:[match range]];
        if ([stringMatch isEqualToString:@"m=audio"]) {
            // enter audio collection state
            collectionState = @"audio";
            continue;
        }
        if ([stringMatch isEqualToString:@"m=video"]) {
            // enter audio video collection state
            collectionState = @"audio";
            continue;
        }
        
        if ([collectionState isEqualToString:@"audio"]) {
            [audioCandidates addObject:[searchedString substringWithRange:[match rangeAtIndex:1]]];
        }
        if ([collectionState isEqualToString:@"video"]) {
            [videoCandidates addObject:[searchedString substringWithRange:[match rangeAtIndex:1]]];
        }
    }

    NSString *removePattern = @"a=(candidate.*)\\r\\n";
    NSRegularExpression* removeRegex = [NSRegularExpression regularExpressionWithPattern:removePattern options:0 error:&error];
    // remove the candidates (we want a candidateless SDP)
    [removeRegex replaceMatchesInString:sdp options:0 range:NSMakeRange(0, [sdp length]) withTemplate:@""];

    return [NSDictionary dictionaryWithObjectsAndKeys:audioCandidates, @"audio",
            videoCandidates, @"video", nil];
}

// TODO: remove when ready
// temporary: until the MMS issue is fixed, try to workaround it by appending the missing part
- (void)workaroundTruncation:(NSMutableString*)sdp
{
    NSString *pattern = @"cnam$";
    NSError  *error = nil;

    NSRegularExpression* regex = [NSRegularExpression regularExpressionWithPattern: pattern options:0 error:&error];
    [regex replaceMatchesInString:sdp options:0 range:NSMakeRange(0, [sdp length]) withTemplate:@"$0e:r5NeEmW7rYyFBr5w"];
}

- (void)processSignalingMessage:(const char *)message type:(int)type
{
    NSParameterAssert(_peerConnection);
    switch (type) {
        case kARDSignalingMessageTypeOffer: {
            // 'type' is @"offer" (we are not the initiator) or @"answer" (we are the initiator) and 'sdp' is the regular SDP
            NSMutableString * msg = [NSMutableString stringWithUTF8String:message];
            //[self workaroundTruncation:msg];
            NSDictionary * candidates = [self incomingFilterCandidatesFromSdp:msg];
            RTCSessionDescription *description = [[RTCSessionDescription alloc] initWithType:@"offer"
                                                                                         sdp:msg];
            [_peerConnection setRemoteDescriptionWithDelegate:self
                                           sessionDescription:description];
            for (NSString * key in candidates) {
                for (NSString * candidate in [candidates objectForKey:key]) {
                    // remember that we have set 'key' to be either 'audio' or 'video' inside incomingFilterCandidatesFromSdp
                    RTCICECandidate *iceCandidate = [[RTCICECandidate alloc] initWithMid:key
                                                                                   index:0
                                                                                     sdp:candidate];
                    [_peerConnection addICECandidate:iceCandidate];
                }
            }
            
            break;

        }
        case kARDSignalingMessageTypeAnswer: {
            // 'type' is @"offer" (we are not the initiator) or @"answer" (we are the initiator) and 'sdp' is the regular SDP
            NSMutableString * msg = [NSMutableString stringWithUTF8String:message];
            [self workaroundTruncation:msg];
            NSDictionary * candidates = [self incomingFilterCandidatesFromSdp:msg];
            RTCSessionDescription *description = [[RTCSessionDescription alloc] initWithType:@"answer"
                                                                                         sdp:msg];
            [_peerConnection setRemoteDescriptionWithDelegate:self
                                           sessionDescription:description];
            
            for (NSString * key in candidates) {
                for (NSString * candidate in [candidates objectForKey:key]) {
                    RTCICECandidate *iceCandidate = [[RTCICECandidate alloc] initWithMid:key
                                                                                   index:0
                                                                                     sdp:candidate];
                    [_peerConnection addICECandidate:iceCandidate];
                }
            }
            
            break;
        }
    }
}

#pragma mark - RTCPeerConnectionDelegate
- (void)peerConnection:(RTCPeerConnection *)peerConnection signalingStateChanged:(RTCSignalingState)stateChanged {
    RCLogNotice("[MediaWebRTC signalingStateChanged:%d]", stateChanged);
}

- (void)peerConnection:(RTCPeerConnection *)peerConnection addedStream:(RTCMediaStream *)stream {
    dispatch_async(dispatch_get_main_queue(), ^{
        RCLogNotice("[MediaWebRTC addedStream] Received %lu video tracks and %lu audio tracks",
              (unsigned long)stream.videoTracks.count,
              (unsigned long)stream.audioTracks.count);
        
        if (stream.videoTracks.count) {
            RTCVideoTrack *videoTrack = stream.videoTracks[0];
            [self.mediaDelegate mediaController:self didReceiveRemoteVideoTrack:videoTrack];
        }
    });
}

- (void)peerConnection:(RTCPeerConnection *)peerConnection removedStream:(RTCMediaStream *)stream {
    RCLogNotice("[MediaWebRTC removedStream]");
}

- (void)peerConnectionOnRenegotiationNeeded:(RTCPeerConnection *)peerConnection {
    RCLogNotice("[MediaWebRTC peerConnectionOnRenegotiationNeeded]");
    //NSLog(@"WARNING: Renegotiation needed but unimplemented.");
}

- (void)peerConnection:(RTCPeerConnection *)peerConnection iceConnectionChanged:(RTCICEConnectionState)newState {
    dispatch_async(dispatch_get_main_queue(), ^{
        RCLogNotice("[MediaWebRTC iceConnectionChanged:%d]", newState);
        if (newState == RTCICEConnectionFailed) {

            NSDictionary *userInfo = @{
                                       NSLocalizedDescriptionKey: @"iceConnectionChanged: ICE connection failed",
                                       };
            NSError *sdpError = [[NSError alloc] initWithDomain:[[RestCommClient sharedInstance] errorDomain]
                                                           code:ERROR_WEBRTC_ICE
                                                       userInfo:userInfo];
            RCLogError("[MediaWebRTC iceConnectionChanged] %s", [[Utilities stringifyDictionary:userInfo] UTF8String]);
            [self.mediaDelegate mediaController:self didError:sdpError];
        }
    });
}

- (void)peerConnection:(RTCPeerConnection *)peerConnection iceGatheringChanged:(RTCICEGatheringState)newState {
    RCLogNotice("[MediaWebRTC iceGatheringChanged:%d]", newState);
    if (newState == RTCICEGatheringComplete) {
        if ([_iceCandidates count] > 0) {
            [self.mediaDelegate mediaController:self didCreateSdp:[self outgoingUpdateSdpWithCandidates:_iceCandidates] isInitiator:_isInitiator];
        }
        else {
            RCLogError("[MediaWebRTC iceGatheringChanged:], state Complete but no candidates collected");
        }
    }
}

- (void)peerConnection:(RTCPeerConnection *)peerConnection gotICECandidate:(RTCICECandidate *)candidate {
    RCLogNotice("[MediaWebRTC gotICECandidate:%s]", [[candidate sdp] UTF8String]);
    [_iceCandidates addObject:candidate];
    /*
    dispatch_async(dispatch_get_main_queue(), ^{
        //ARDICECandidateMessage *message = [[ARDICECandidateMessage alloc] initWithCandidate:candidate];
        //[self sendSignalingMessage:message];
        
    });
     */
}

- (void)peerConnection:(RTCPeerConnection*)peerConnection didOpenDataChannel:(RTCDataChannel*)dataChannel {
    RCLogNotice("[MediaWebRTC didOpenDataChannel]");
}

#pragma mark - RTCSessionDescriptionDelegate
- (void)peerConnection:(RTCPeerConnection *)peerConnection didCreateSessionDescription:(RTCSessionDescription *)sdp
                 error:(NSError *)error
{
    dispatch_async(dispatch_get_main_queue(), ^{
        RCLogNotice("[MediaWebRTC didCreateSessionDescription]");
        if (error) {
            RCLogError("[MediaWebRTC didCreateSessionDescription] Failed to create session description. Error: %s", [[Utilities stringifyDictionary:[error userInfo]] UTF8String]);
            [self disconnect];

            NSDictionary *userInfo = @{
                                       NSLocalizedDescriptionKey: @"didCreateSessionDescription: Failed to create session description",
                                       };
            NSError *sdpError = [[NSError alloc] initWithDomain:[[RestCommClient sharedInstance] errorDomain]
                                                           code:ERROR_WEBRTC_SDP
                                                       userInfo:userInfo];
            [self.mediaDelegate mediaController:self didError:sdpError];
            return;
        }
        [_peerConnection setLocalDescriptionWithDelegate:self
                                      sessionDescription:sdp];

        // keep the SDP around; we'll be using it when all ICE candidates are downloaded
        self.sdp = sdp.description;
        /* We don't need to send the SDP here; we will be using Sofia SIP facilities for that
        ARDSessionDescriptionMessage *message =
        [[ARDSessionDescriptionMessage alloc] initWithDescription:sdp];
        [self sendSignalingMessage:message];
         */
    });
}

- (void)peerConnection:(RTCPeerConnection *)peerConnection didSetSessionDescriptionWithError:(NSError *)error {
    dispatch_async(dispatch_get_main_queue(), ^{
        RCLogNotice("[MediaWebRTC didSetSessionDescriptionWithError]");
        if (error) {
            RCLogError("[MediaWebRTC didSetSessionDescriptionWithError] Failed to set session description. Error: %s", [[Utilities stringifyDictionary:[error userInfo]] UTF8String]);

            [self disconnect];
            NSDictionary *userInfo = @{
                                       NSLocalizedDescriptionKey: @"didSetSessionDescriptionWithError: Failed to set session description",
                                       };
            NSError *sdpError =[[NSError alloc] initWithDomain:[[RestCommClient sharedInstance] errorDomain]
                                                          code:ERROR_WEBRTC_SDP
                                                      userInfo:userInfo];

            [self.mediaDelegate mediaController:self didError:sdpError];
            return;
        }
        
        // If we're answering and we've just set the remote offer we need to create
        // an answer and set the local description.
        if (!_isInitiator && !_peerConnection.localDescription) {
            RTCMediaConstraints *constraints = [self defaultAnswerConstraints];
            [_peerConnection createAnswerWithDelegate:self
                                          constraints:constraints];
            
        }
    });
}


@end
