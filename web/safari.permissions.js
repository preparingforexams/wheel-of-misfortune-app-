function requestDeviceMotionEventPermission(callback) {
    let requestPermission = DeviceMotionEvent.requestPermission;
    if (typeof requestPermission === "function") {
        requestPermission()
            .then(callback)
            .catch((_) => callback(null));
    }

    callback(null);
}
