function requestDeviceMotionEventPermission(callback) {
    if (typeof DeviceMotionEvent.requestPermission === "function") {
        DeviceMotionEvent.requestPermission()
            .then(callback)
            .catch((_) => callback(null));
    }

    callback(null);
}
