//
//  GameKitHelper.m
//  CatRaceStarter
//
//  Created by Kauserali on 02/01/14.
//  Copyright (c) 2014 Raywenderlich. All rights reserved.
//

#import "GameKitHelper.h"
#import "GameViewController.h"

NSString *const PresentAuthenticationViewController = @"present_authentication_view_controller";
NSString *const RemoveAuthenticationViewController = @"remove_authentication_view_controller";
NSString *const LocalPlayerIsAuthenticated = @"local_player_authenticated";

@implementation GameKitHelper {
    BOOL _enableGameCenter;
    BOOL _matchStarted;
    GameViewController *_gameViewController;
    GKMatchmakerViewController *_mmvc;
}

@synthesize pendingInvite;
@synthesize pendingPlayersToInvite;

+ (instancetype)sharedGameKitHelper
{
    static GameKitHelper *sharedGameKitHelper;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedGameKitHelper = [[GameKitHelper alloc] init];
    });
    return sharedGameKitHelper;
}

- (id)init
{
    self = [super init];
    if (self) {
        _enableGameCenter = YES;
    }
    return self;
}

- (void)authenticateLocalPlayer
{
    //1
    GKLocalPlayer *localPlayer = [GKLocalPlayer localPlayer];
    
    if (localPlayer.isAuthenticated) {
        [[NSNotificationCenter defaultCenter] postNotificationName:LocalPlayerIsAuthenticated object:nil];
        return;
    }
    //2
    localPlayer.authenticateHandler  =
    ^(UIViewController *viewController, NSError *error) {
        //3
        [self setLastError:error];
        
        if(viewController != nil) {
            //4
            [self setAuthenticationViewController:viewController];
        } else if([GKLocalPlayer localPlayer].isAuthenticated) {
            NSLog(@"player authenticated");
            [[GKLocalPlayer localPlayer] unregisterAllListeners];
            [[GKLocalPlayer localPlayer] registerListener:self];
            
            //5
            _enableGameCenter = YES;
            [[NSNotificationCenter defaultCenter] postNotificationName:LocalPlayerIsAuthenticated object:nil];
        } else {
            //6
            _enableGameCenter = NO;
        }
    };
}

- (void)player:(GKPlayer *)player didAcceptInvite:(GKInvite *)invite
{
       
        NSLog(@"Invite accepted!");
    self.pendingInvite = invite;
    
    NSLog(@"invite = %@",invite);
    [[GKMatchmaker sharedMatchmaker] matchForInvite:invite completionHandler:^(GKMatch *match, NSError *error) {
        
        if (error) {
            NSLog(@"Error creating match from invitation: %@", [error description]);
            //Tell ViewController that match connect failed
        }
        else {
            [self updateWithMatch:match];
        }
    }];
}

-(void)updateWithMatch:(GKMatch*)match {
    self.match = match;
    _match.delegate = self;
}

-(void)player:(GKPlayer *)player didRequestMatchWithRecipients:(NSArray *)recipientPlayers
{
    NSLog(@"didRequestMatchWithRecipients activated");
    self.pendingPlayersToInvite = recipientPlayers;
    
    NSLog(@"recipientPlayers = %@", recipientPlayers);
    [_gameViewController dismissViewControllerAnimated:YES completion:nil];
    
}

- (void)lookupPlayers {
    
    NSLog(@"Looking up %lu players...", (unsigned long)_match.playerIDs.count);
    
    [GKPlayer loadPlayersForIdentifiers:_match.playerIDs withCompletionHandler:^(NSArray *players, NSError *error) {
        
        if (error != nil) {
            NSLog(@"Error retrieving player info: %@", error.localizedDescription);
            _matchStarted = NO;
            [_delegate matchEnded];
        } else {
            
            // Populate players dict
            _playersDict = [NSMutableDictionary dictionaryWithCapacity:players.count];
            for (GKPlayer *player in players) {
                NSLog(@"Found player: %@", player.alias);
                [_playersDict setObject:player forKey:player.playerID];
            }
            [_playersDict setObject:[GKLocalPlayer localPlayer] forKey:[GKLocalPlayer localPlayer].playerID];
            
            // Notify delegate match can begin
            _matchStarted = YES;
            [_delegate matchStarted];
        }
    }];
}

- (void)findMatchWithMinPlayers:(int)minPlayers maxPlayers:(int)maxPlayers
                 viewController:(UIViewController *)viewController
                       delegate:(id<GameKitHelperDelegate>)delegate {
    NSLog(@"findMatchWithMinPlayers activated");
    if (!_enableGameCenter) return;
    
    _matchStarted = NO;
    self.match = nil;
    viewController = viewController;
    _delegate = delegate;
    
    if (pendingInvite != nil) {
        NSLog(@"pendingInvite != nil");
        [viewController dismissViewControllerAnimated:NO completion:nil];
        _mmvc = [[GKMatchmakerViewController alloc] initWithInvite:pendingInvite];
        _mmvc.matchmakerDelegate = self;
        [viewController presentViewController:_mmvc animated:YES completion:nil];
        self.pendingInvite = nil;
    }
    else{
        NSLog(@"pendingInvite == nil");
        [viewController dismissViewControllerAnimated:NO completion:nil];
        GKMatchRequest *request = [[GKMatchRequest alloc] init];
        request.minPlayers = minPlayers;
        request.maxPlayers = maxPlayers;
        request.recipients = pendingPlayersToInvite;
        request.recipientResponseHandler = ^(GKPlayer *player, GKInviteeResponse response)
        {
            NSLog(@"response = %ld",(long)response);
            if (response == GKInviteeResponseAccepted)
            {
                NSLog(@"DEBUG: Player Accepted: %@", player);
                // Tell the infrastructure we are done matching and will start using the match
                [viewController dismissViewControllerAnimated:YES completion:nil];
            }
        };
        _mmvc =
        [[GKMatchmakerViewController alloc] initWithMatchRequest:request];
        _mmvc.matchmakerDelegate = self;
        
        //vvv this is what displays the view controller when the game loads
        [viewController presentViewController:_mmvc animated:YES completion:nil];

        self.pendingPlayersToInvite = nil;
    }
}

- (void)setAuthenticationViewController:
(UIViewController *)authenticationViewController
{
    if (authenticationViewController != nil) {
        _authenticationViewController = authenticationViewController;
        [[NSNotificationCenter defaultCenter]
         postNotificationName:PresentAuthenticationViewController
         object:self];
    }
    
}

- (void)removeAuthenticationViewController
{
    [[NSNotificationCenter defaultCenter]
    postNotificationName:RemoveAuthenticationViewController
    object:self];
}

- (void)setLastError:(NSError *)error
{
    _lastError = [error copy];
    if (_lastError) {
        NSLog(@"GameKitHelper ERROR: %@",
              [[_lastError userInfo] description]);
    }
}

#pragma mark GKMatchmakerViewControllerDelegate

// The user has cancelled matchmaking
- (void)matchmakerViewControllerWasCancelled:(GKMatchmakerViewController *)viewController {
    [viewController dismissViewControllerAnimated:YES completion:nil];
}

// Matchmaking has failed with an error
- (void)matchmakerViewController:(GKMatchmakerViewController *)viewController didFailWithError:(NSError *)error {
    [viewController dismissViewControllerAnimated:YES completion:nil];
    NSLog(@"Error finding match: %@", error.localizedDescription);
}

// A peer-to-peer match has been found, the game should start
- (void)matchmakerViewController:(GKMatchmakerViewController *)viewController didFindMatch:(GKMatch *)match {
    NSLog(@"didFindMatch activated");
    [viewController dismissViewControllerAnimated:YES completion:nil];
    self.match = match;
    match.delegate = self;
    if (!_matchStarted && match.expectedPlayerCount == 0) {
        NSLog(@"Ready to start match! in didFindMatch");
        [self lookupPlayers];
    }
}



#pragma mark GKMatchDelegate

// The match received data sent from the player.
- (void)match:(GKMatch *)match didReceiveData:(NSData *)data fromPlayer:(NSString *)playerID {
    if (_match != match) return;
    
    [_delegate match:match didReceiveData:data fromPlayer:playerID];
}



// The player state changed (eg. connected or disconnected)
- (void)match:(GKMatch *)match player:(NSString *)playerID didChangeState:(GKPlayerConnectionState)state {
    if (_match != match) return;
    
    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
    [self matchmakerViewControllerWasCancelled:_mmvc];
    }];
    
    switch (state) {
        case GKPlayerStateConnected:
            // handle a new player connection.
            NSLog(@"Player connected!");
            NSLog(@"expectedPlayerCount = %lu",(unsigned long)match.expectedPlayerCount);
            
            if (!_matchStarted && match.expectedPlayerCount == 0) {
                NSLog(@"Ready to start match! in didChangeState");
                [self lookupPlayers];
            }
            
            break;
        case GKPlayerStateDisconnected:
            // a player just disconnected.
            NSLog(@"Player disconnected!");
            _matchStarted = NO;
            [_delegate matchEnded];
            break;
    }
}

// The match was unable to connect with the player due to an error.
- (void)match:(GKMatch *)match connectionWithPlayerFailed:(NSString *)playerID withError:(NSError *)error {
    
    if (_match != match) return;
    
    NSLog(@"Failed to connect to player with error: %@", error.localizedDescription);
    _matchStarted = NO;
    [_delegate matchEnded];
}

// The match was unable to be established with any players due to an error.
- (void)match:(GKMatch *)match didFailWithError:(NSError *)error {
    
    if (_match != match) return;
    
    NSLog(@"Match failed with error: %@", error.localizedDescription);
    _matchStarted = NO;
    [_delegate matchEnded];
}
@end
