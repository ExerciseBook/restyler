module SpecHelper
    ( TestApp(..)
    , testApp
    , runTestApp
    , someRestyler

    -- * Config
    , loadDefaultConfig
    , testRestylers

    -- * Re-exports
    , module X
    )
where

import Restyler.Prelude as X hiding
    (readFileBinary, readFileUtf8, writeFileUtf8)
import Test.Hspec as X hiding
    ( expectationFailure
    , shouldBe
    , shouldContain
    , shouldEndWith
    , shouldMatchList
    , shouldNotBe
    , shouldNotContain
    , shouldNotReturn
    , shouldNotSatisfy
    , shouldReturn
    , shouldSatisfy
    , shouldStartWith
    )
import Test.Hspec.Expectations.Lifted as X
import Test.QuickCheck as X

import Data.Yaml (decodeThrow)
import Restyler.App.Class
import Restyler.Config
import Restyler.Options
import Restyler.Restyler
import RIO.Test.FS (FS, HasFS(..))
import qualified RIO.Test.FS as FS

-- | A versatile app for use with @'runRIO'@
--
-- Be sure to construct valid actions for the fields exercised in your test. The
-- initialization function (@'testApp'@) sets them all to @'error'@ values.
--
data TestApp = TestApp
    { taLogFunc :: LogFunc
    , taOptions :: Options

    -- System
    , taFS :: FS

    -- Process
    , taCallProcess :: String -> [String] -> RIO TestApp ()
    , taCallProcessExitCode :: String -> [String] -> RIO TestApp ExitCode
    , taReadProcess :: String -> [String] -> String -> RIO TestApp String

    -- Add our other capabilities if/when tests require them
    }

testApp :: FilePath -> [(FilePath, Text)] -> IO TestApp
testApp cwd files = do
    fs <- FS.build cwd files

    pure TestApp
        { taLogFunc = mkLogFunc $ \_ _ _ _ -> pure ()
        , taOptions = testOptions
        , taFS = fs
        , taCallProcess = error "callProcess"
        , taCallProcessExitCode = error "callProcessExitCode"
        , taReadProcess = error "readProcess"
        }

runTestApp :: RIO TestApp a -> IO a
runTestApp f = do
    app <- testApp "/" []
    runRIO app f

testOptions :: Options
testOptions = Options
    { oAccessToken = error "oAccessToken"
    , oLogLevel = error "oLogLevel"
    , oLogColor = error "oLogColor"
    , oOwner = error "oOwner"
    , oRepo = error "oRepo"
    , oPullRequest = error "oPullRequest"
    , oJobUrl = error "oJobUrl"
    , oHostDirectory = Nothing
    , oUnrestricted = False
    }

instance HasLogFunc TestApp where
    logFuncL = lens taLogFunc $ \x y -> x { taLogFunc = y }

instance HasOptions TestApp where
    optionsL = lens taOptions $ \x y -> x { taOptions = y }

instance HasFS TestApp where
    fsL = lens taFS $ \x y -> x { taFS = y }

instance HasSystem TestApp where
    readFile = FS.readFileUtf8
    readFileBS = FS.readFileBinary
    getCurrentDirectory = FS.getCurrentDirectory
    setCurrentDirectory = FS.setCurrentDirectory
    doesFileExist = FS.doesFileExist
    doesDirectoryExist = FS.doesDirectoryExist
    isFileExecutable = FS.isFileExecutable
    listDirectory = FS.listDirectory

instance HasProcess TestApp where
    callProcess = asksAp2 taCallProcess
    callProcessExitCode = asksAp2 taCallProcessExitCode
    readProcess = asksAp3 taReadProcess

someRestyler :: Restyler
someRestyler = Restyler
    { rEnabled = True
    , rName = "test-restyler"
    , rImage = "restyled/restyler-test-restyler"
    , rCommand = ["restyle"]
    , rDocumentation = []
    , rArguments = []
    , rInclude = ["**/*"]
    , rInterpreters = []
    , rSupportsArgSep = True
    , rSupportsMultiplePaths = True
    }

-- | @'asks'@ for a function of 2 arguments
asksAp2 :: MonadReader r m => (r -> a -> b -> m c) -> a -> b -> m c
asksAp2 f x y = do
    f' <- asks f
    f' x y

-- | Same, but apply it to 3 arguments
asksAp3 :: MonadReader r m => (r -> a -> b -> c -> m d) -> a -> b -> c -> m d
asksAp3 f x y z = do
    f' <- asks f
    f' x y z

loadDefaultConfig :: RIO env Config
loadDefaultConfig = do
    config <- decodeThrow defaultConfigContent
    resolveRestylers config testRestylers

testRestylers :: [Restyler]
testRestylers =
    [ someRestyler { rName = "astyle" }
    , someRestyler { rName = "autopep8" }
    , someRestyler { rName = "black" }
    , someRestyler { rName = "dfmt" }
    , someRestyler { rName = "elm-format" }
    , someRestyler { rName = "hindent", rEnabled = False }
    , someRestyler { rName = "jdt", rEnabled = False }
    , someRestyler { rName = "pg_format" }
    , someRestyler { rName = "php-cs-fixer" }
    , someRestyler { rName = "prettier" }
    , someRestyler { rName = "prettier-markdown" }
    , someRestyler { rName = "prettier-ruby" }
    , someRestyler { rName = "prettier-yaml" }
    , someRestyler { rName = "reorder-python-imports" }
    , someRestyler { rName = "rubocop" }
    , someRestyler { rName = "rustfmt" }
    , someRestyler { rName = "shellharden" }
    , someRestyler { rName = "shfmt" }
    , someRestyler { rName = "stylish-haskell" }
    , someRestyler { rName = "terraform" }
    , someRestyler { rName = "yapf" }
    ]
