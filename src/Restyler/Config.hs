{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}

module Restyler.Config
    ( Config(..)
    , whenConfig
    , whenConfigNonEmpty
    , whenConfigJust
    , defaultConfig
    , configPath
    )
where

import Restyler.Prelude

import Data.Aeson
import Data.Aeson.Casing
import Data.Aeson.Types (typeMismatch)
import Data.Bool (bool)
import qualified Data.List.NonEmpty as NE
import qualified Data.Vector as V
import Restyler.Config.ExpectedKeys
import Restyler.Config.RequestReview
import Restyler.Config.Statuses
import Restyler.RemoteFile
import Restyler.Restyler

-- | Top-level configuration object
data Config = Config
    { cEnabled :: Bool
    -- ^ Do anything at all?
    , cAuto :: Bool
    -- ^ Just push the restyling, don't comment?
    , cRemoteFiles :: [RemoteFile]
    -- ^ Any remote configuration files to fetch before restyling
    , cCommentsEnabled :: Bool
    -- ^ Leave Comments?
    , cStatuses :: Statuses
    -- ^ Send PR statuses?
    , cRequestReview :: Maybe RequestReviewConfig
    -- ^ Request review for Restyle PRs?
    , cLabels :: [Name IssueLabel]
    -- ^ Labels to add to Restyle PRs
    , cRestylers :: [Restyler]
    -- ^ What restylers to run
    }
    deriving (Eq, Show, Generic)

instance FromJSON Config where
    parseJSON (Array v) = do
        restylers <- mapM parseJSON (V.toList v)
        pure defaultConfig { cRestylers = restylers }
    parseJSON (Object o) = do
        validateObjectKeys
            [ "enabled"
            , "auto"
            , "remote_files"
            , "comments"
            , "statuses"
            , "request_review"
            , "labels"
            , "restylers"
            ]
            o
        Config
            <$> o .:? "enabled" .!= cEnabled defaultConfig
            <*> o .:? "auto" .!= cAuto defaultConfig
            <*> o .:? "remote_files" .!= cRemoteFiles defaultConfig
            <*> o .:? "comments" .!= cCommentsEnabled defaultConfig
            <*> o .:? "statuses" .!= cStatuses defaultConfig
            <*> o .:? "request_review" .!= cRequestReview defaultConfig
            <*> o .:? "labels" .!= cLabels defaultConfig
            <*> o .:? "restylers" .!= cRestylers defaultConfig
    parseJSON v = typeMismatch "Config object or list of restylers" v

instance ToJSON Config where
    toJSON = genericToJSON $ aesonPrefix snakeCase
    toEncoding = genericToEncoding $ aesonPrefix snakeCase

whenConfig :: MonadReader env m => (env -> Bool) -> m () -> m ()
whenConfig getConfig act =
    whenConfigJust (bool Nothing (Just ()) . getConfig) (const act)

whenConfigNonEmpty :: MonadReader env m => (env -> [a]) -> ([a] -> m ()) -> m ()
whenConfigNonEmpty getConfig act =
    whenConfigJust (NE.nonEmpty . getConfig) (act . NE.toList)

whenConfigJust :: MonadReader env m => (env -> Maybe a) -> (a -> m ()) -> m ()
whenConfigJust getConfig act = traverse_ act =<< asks getConfig

-- | Default configuration
--
-- - Enabled
-- - Not Auto
-- - Leave comments
-- - Send statuses
-- - Don't request review
-- - No labels
-- - Run most restylers
--
defaultConfig :: Config
defaultConfig = Config
    { cEnabled = True
    , cAuto = False
    , cRemoteFiles = []
    , cCommentsEnabled = True
    , cStatuses = defaultStatusesConfig
    , cRequestReview = Nothing
    , cLabels = []
    , cRestylers = defaultRestylers
    }

-- | @.restyled.yaml@
configPath :: FilePath
configPath = ".restyled.yaml"
