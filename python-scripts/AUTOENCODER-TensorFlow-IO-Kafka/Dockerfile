FROM tensorflow/tensorflow:2.9.1

# RUN python3 -m pip install tensorflow-io-nightly==0.10.0.dev2126 --no-deps
RUN python3 -m pip install tensorflow-io
RUN python3 -m pip install kafka-python

RUN python3 -m pip install avro
RUN python3 -m pip install confluent_kafka

# For reading from the bucket
# RUN python3 -m pip install -U 'protobuf>=3.4.0'
# RUN python3 -m pip install -U 'absl-py==0.9'
# RUN python3 -m pip install -U 'google-api-core-14.3'--force-reinstall
# RUN python3 -m pip install google-cloud-storage==1.19.0 tensorflow-datasets==1.1.0
RUN python3 -m pip install google-cloud-storage tensorflow-datasets

ADD . /v

WORKDIR /v

