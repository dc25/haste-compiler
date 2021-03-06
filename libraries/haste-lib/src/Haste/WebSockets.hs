{-# LANGUAGE FlexibleInstances, EmptyDataDecls, OverloadedStrings #-}
-- | WebSockets API for Haste.
module Haste.WebSockets (
    module Haste.Concurrent,
    WebSocket,
    withWebSocket, withBinaryWebSocket, wsSend, wsSendBlob
  ) where
import Haste
import Haste.Foreign
import Haste.Concurrent
import Haste.Binary (Blob)
import Unsafe.Coerce

newtype WSOnMsg = WSOnMsg (WebSocket -> JSString -> IO ())
newtype WSOnBinMsg = WSOnBinMsg (WebSocket -> Blob -> IO ())
newtype WSComputation = WSComputation (WebSocket -> IO ())
newtype WSOnError = WSOnError (IO ())
data WebSocket

instance Pack WebSocket where
  pack = unsafeCoerce
instance Pack WSOnMsg where
  pack = unsafeCoerce
instance Pack WSOnBinMsg where
  pack = unsafeCoerce
instance Pack WSComputation where
  pack = unsafeCoerce
instance Pack WSOnError where
  pack = unsafeCoerce

instance Unpack WebSocket where
  unpack = unsafeCoerce
instance Unpack WSOnMsg where
  unpack = unsafeCoerce
instance Unpack WSOnBinMsg where
  unpack = unsafeCoerce
instance Unpack WSComputation where
  unpack = unsafeCoerce
instance Unpack WSOnError where
  unpack = unsafeCoerce

-- | Run a computation with a web socket. The computation will not be executed
--   until a connection to the server has been established.
withWebSocket :: URL
              -- ^ URL to bind the WebSocket to
              -> (WebSocket -> JSString -> CIO ())
              -- ^ Computation to run when new data arrives
              -> CIO a
              -- ^ Computation to run when an error occurs
              -> (WebSocket -> CIO a)
              -- ^ Computation using the WebSocket
              -> CIO a
withWebSocket url cb err f = do
    result <- newEmptyMVar
    let f' = WSComputation $ \ws -> concurrent $ f ws >>= putMVar result
    liftIO $ new url cb' f' $ WSOnError $ concurrent $ err >>= putMVar result
    takeMVar result
  where
    cb' = WSOnMsg $ \ws msg -> concurrent $ cb ws msg

-- | Run a computation with a web socket. The computation will not be executed
--   until a connection to the server has been established.
withBinaryWebSocket :: URL
              -- ^ URL to bind the WebSocket to
              -> (WebSocket -> Blob -> CIO ())
              -- ^ Computation to run when new data arrives
              -> CIO a
              -- ^ Computation to run when an error occurs
              -> (WebSocket -> CIO a)
              -- ^ Computation using the WebSocket
              -> CIO a
withBinaryWebSocket url cb err f = do
    result <- newEmptyMVar
    let f' = WSComputation $ \ws -> concurrent $ f ws >>= putMVar result
    liftIO $ newBin url cb' f' $ WSOnError $ concurrent $ err >>= putMVar result
    takeMVar result
  where
    cb' = WSOnBinMsg $ \ws msg -> concurrent $ cb ws msg

new :: URL
    -> WSOnMsg
    -> WSComputation
    -> WSOnError
    -> IO ()
new = ffi "(function(url, cb, f, err) {\
             \var ws = new WebSocket(url);\
             \ws.onmessage = function(e) {B(A(cb,[ws, [0,e.data],0]));};\
             \ws.onopen = function(e) {B(A(f,[ws,0]));};\
             \ws.onerror = function(e) {B(A(err,[0]));};\
             \return ws;\
           \})" 

newBin :: URL
    -> WSOnBinMsg
    -> WSComputation
    -> WSOnError
    -> IO ()
newBin = ffi "(function(url, cb, f, err) {\
                \var ws = new WebSocket(url);\
                \ws.binaryType = 'blob';\
                \ws.onmessage = function(e) {B(A(cb,[ws,e.data,0]));};\
                \ws.onopen = function(e) {B(A(f,[ws,0]));};\
                \ws.onerror = function(e) {B(A(err,[0]));};\
                \return ws;\
              \})" 

-- | Send a string over a WebSocket.
wsSend :: WebSocket -> JSString -> CIO ()
wsSend ws str = liftIO $ sendS ws str

-- | Send a Blob over a WebSocket.
wsSendBlob :: WebSocket -> Blob -> CIO ()
wsSendBlob ws b = liftIO $ sendB ws b

sendS :: WebSocket -> JSString -> IO ()
sendS = ffi "(function(s, msg) {s.send(msg);})"

sendB :: WebSocket -> Blob -> IO ()
sendB = ffi "(function(s, msg) {s.send(msg);})"
