#!/bin/bash
# Save output data from a Persistent Volume on a Kubernetes cluster.

# parse command-line arguments
if [[ $# != 2 ]]; then
	echo "usage: $0 <pvc-name> <remote-path>"
	exit -1
fi

PVC_NAME="$1"
PVC_PATH="/workspace"
POD_FILE="pod.yaml"
POD_NAME="data-saver"
REMOTE_PATH="$2"

# create pod config file
cat > $POD_FILE <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: $POD_NAME
spec:
  containers:
  - name: $POD_NAME
    image: ubuntu
    args: ["sleep", "infinity"]
    volumeMounts:
    - mountPath: $PVC_PATH
      name: $PVC_NAME
  restartPolicy: Never
  volumes:
    - name: $PVC_NAME
      persistentVolumeClaim:
        claimName: $PVC_NAME
EOF

# create pod
kubectl create -f $POD_FILE

# wait for pod to initialize
POD_STATUS=""

while [[ $POD_STATUS != "Running" ]]; do
	sleep 1
	POD_STATUS="$(kubectl get pods --no-headers $POD_NAME | awk '{ print $3 }')"
	POD_STATUS="$(echo $POD_STATUS)"
done

# copy output data from pod
echo "copying data..."

kubectl exec $POD_NAME -- bash -c "for f in \$(find $PVC_PATH/$USER/$REMOTE_PATH -type l); do cp --remove-destination \$(readlink \$f) \$f; done"
kubectl cp "$POD_NAME:$PVC_PATH/$USER/$REMOTE_PATH" "$(basename $REMOTE_PATH)"

# delete pod
kubectl delete -f $POD_FILE
rm -f $POD_FILE
