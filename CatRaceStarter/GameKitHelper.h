//
//  GameKitHelper.h
//  CatRaceStarter
//
//  Created by Kauserali on 02/01/14.
//  Copyright (c) 2014 Raywenderlich. All rights reserved.
//


@import GameKit;

@protocol GameKitHelperDelegate
- (void)matchStarted;
- (void)matchEnded;
- (void)match:(GKMatch *)match didReceiveData:(NSData *)data
   fromPlayer:(NSString *)playerID;
- (void)inviteReceived;
@end

extern NSString *const PresentAuthenticationViewController;
extern NSString *const RemoveAuthenticationViewController;
extern NSString *const LocalPlayerIsAuthenticated;

@interface GameKitHelper : NSObject<GKMatchmakerViewControllerDelegate, GKMatchDelegate, GKLocalPlayerListener>{
    GKInvite *pendingInvite;
    NSArray *pendingPlayersToInvite;
}
@property (retain) GKInvite *pendingInvite;
@property (retain) NSArray *pendingPlayersToInvite;

@property (nonatomic, readonly) UIViewController *authenticationViewController;
@property (nonatomic, readonly) NSError *lastError;

@property (nonatomic, strong) GKMatch *match;
@property (nonatomic, assign) id <GameKitHelperDelegate> delegate;
@property (nonatomic, strong) NSMutableDictionary *playersDict;

+ (instancetype)sharedGameKitHelper;
- (void)authenticateLocalPlayer;

- (void)destroyMMVC:(UIViewController *)viewController;
- (void)findMatchWithMinPlayers:(int)minPlayers maxPlayers:(int)maxPlayers
                 viewController:(UIViewController *)viewController
                       delegate:(id<GameKitHelperDelegate>)theDelegate;
@end
