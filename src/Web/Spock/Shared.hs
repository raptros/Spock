{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE DoAndIfThenElse #-}
{-# LANGUAGE RankNTypes #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE DataKinds #-}
module Web.Spock.Shared
    (-- * Helpers for running Spock
      runSpock, spockAsApp
     -- * Handeling requests
    , request, header, cookie, body, jsonBody, jsonBody', files, UploadedFile (..)
    , params, param, param'
     -- * Sending responses
    , setStatus, setHeader, redirect, jumpNext, setCookie, setCookie', bytes, lazyBytes
    , text, html, file, json, blaze
      -- * Middleware helpers
    , middlewarePass, modifyVault, queryVault
      -- * Database
    , PoolOrConn (..), ConnBuilder (..), PoolCfg (..)
      -- * Accessing Database and State
    , HasSpock (runQuery, getState), SpockConn, SpockState, SpockSession
      -- * Basic HTTP-Auth
    , requireBasicAuth
     -- * Sessions
    , SessionCfg (..), SessionId
    , getSessionId, readSession, writeSession, modifySession, clearAllSessions
     -- * Digestive Functors
    , runForm
     -- * Internals for extending Spock
    , getSpockHeart, runSpockIO, WebStateM, WebState
    )
where

import Web.Spock.Internal.Monad
import Web.Spock.Internal.Digestive
import Web.Spock.Internal.SessionManager
import Web.Spock.Internal.Types
import Web.Spock.Internal.CoreAction
import Control.Monad
import qualified Web.Spock.Internal.Wire as W
import qualified Network.Wai as Wai
import qualified Network.Wai.Handler.Warp as Warp

-- | Run a Spock application. Basically just a wrapper aroung @Warp.run@.
runSpock :: Warp.Port -> IO Wai.Middleware -> IO ()
runSpock port mw =
    do putStrLn ("Spock is running on port " ++ show port)
       app <- spockAsApp mw
       Warp.run port app

-- | Convert a middleware to an application. All failing requests will
-- result in a 404 page
spockAsApp :: IO Wai.Middleware -> IO Wai.Application
spockAsApp = liftM W.middlewareToApp

-- | Get the current users sessionId. Note that this ID should only be
-- shown to it's owner as otherwise sessions can be hijacked.
getSessionId :: SpockAction conn sess st SessionId
getSessionId =
    getSessMgr >>= sm_getSessionId

-- | Write to the current session. Note that all data is stored on the server.
-- The user only reciedes a sessionId to be identified.
writeSession :: sess -> SpockAction conn sess st ()
writeSession d =
    do mgr <- getSessMgr
       (sm_writeSession mgr) d

-- | Modify the stored session
modifySession :: (sess -> sess) -> SpockAction conn sess st ()
modifySession f =
    do mgr <- getSessMgr
       (sm_modifySession mgr) f

-- | Read the stored session
readSession :: SpockAction conn sess st sess
readSession =
    do mgr <- getSessMgr
       sm_readSession mgr

-- | Globally delete all existing sessions. This is useful for example if you want
-- to require all users to relogin
clearAllSessions :: SpockAction conn sess st ()
clearAllSessions =
    do mgr <- getSessMgr
       sm_clearAllSessions mgr
