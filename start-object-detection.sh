#!/bin/bash -e

sudo snap install jq

export DETECTION_MODEL=/opt/intel/openvino/deployment_tools/open_model_zoo/tools/downloader/intel/yolo-v2-tiny-ava-0001/FP32/yolo-v2-tiny-ava-0001.xml
export DETECTION_MODEL_PROC=/opt/intel/openvino/data_processing/dl_streamer/samples/model_proc/intel/object_detection/yolo-v2-tiny-ava-0001.json

# echo "Starting device camera usb streaming"
# curl -X PUT -d '{
#     "StartStreaming": {
#       "InputFps": "5"
#     }
# }' http://localhost:59882/api/v2/device/name/example-camera/StartStreaming

# echo "Initializing openVINO environment"
# cd ~/intel/openvino_2021/bin/
# ./setupvars.sh

echo "Querying core data for the rtsp URL"
code=$(curl --show-error --silent --include \
    --output /dev/null --write-out "%{http_code}" \
    -X GET http://localhost:59882/api/v2/device/name/example-camera/StreamURI)
if [[ $code != 200 ]]; then
    echo "Error on querying core data for the rtsp URL. exiting"
    exit 1
else
    RRTSP_URL=$(curl -s http://localhost:59882/api/v2/device/name/example-camera/StreamURI | jq -r '.event.readings | .[] | .value')
    echo "Starting object detection demo"
    gst-launch-1.0 \
	urisourcebin uri=$RRTSP_URL ! decodebin ! \
	gvadetect model=${DETECTION_MODEL} model_proc=${DETECTION_MODEL_PROC} device=CPU ! queue ! \
	gvametaconvert add-empty-results=true format=json ! queue ! \
	gvametapublish address=localhost:1883 method=mqtt topic=openvino/device-mqtt-test/json mqtt-client-id=testID qos=true ! queue ! \
	gvawatermark ! videoconvert ! fpsdisplaysink video-sink=autovideosink sync=false

fi