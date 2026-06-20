"""Simple Python microservice for Kubernetes + Istio deployment."""

import os
import socket
from flask import Flask, jsonify

app = Flask(__name__)

SERVICE_NAME = os.getenv("SERVICE_NAME", "pyapp")
SERVICE_VERSION = os.getenv("SERVICE_VERSION", "1.0.0")


@app.route("/")
def index():
    return jsonify(
        service=SERVICE_NAME,
        version=SERVICE_VERSION,
        hostname=socket.gethostname(),
        
        #TODO: dynamically get the version from an environment variable or config map
        message=
'''Hello from inside the mesh you filthy animal!
application version: 1.3.0''',

    )


@app.route("/health/live")
def liveness():
    return jsonify(status="alive"), 200


@app.route("/health/ready")
def readiness():
    return jsonify(status="ready"), 200


@app.route("/info")
def info():
    return jsonify(
        service=SERVICE_NAME,
        version=SERVICE_VERSION,
        hostname=socket.gethostname(),
        pod_ip=os.getenv("POD_IP", "unknown"),
        node_name=os.getenv("NODE_NAME", "unknown"),
    )


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080)
