import numpy as np
import avro.schema
import tensorflow as tf
import tensorflow_io as tfio
import tensorflow_io.kafka as kafka_io
import tensorflow_datasets as tfds
from google.cloud import storage
from kafka import KafkaProducer
import io
from confluent_kafka import Consumer, KafkaError
from avro.io import DatumReader, BinaryDecoder

kafka_config = [
    # "broker.version.fallback=0.10.0.0",
    # "security.protocol=sasl_plaintext",
    # "sasl.username=test",
    # "sasl.password=test123",
    # "sasl.mechanisms=PLAIN"
    # Tried to force kafka library to use the correct address
    "bootstrap.servers=kafka.confluent.svc.cluster.local:9071",
    # "enable.partition.eof=false"
]

import sys

print("Options: ", sys.argv)

if len(sys.argv) != 8:
    print("Usage: python3 cardata-v1.py <servers> <topic> <offset> <result_topic> <mode> <model-file> <project>")
    sys.exit(1)

servers = sys.argv[1]
topic = sys.argv[2]
offset = sys.argv[3]
result_topic = sys.argv[4]
mode = sys.argv[5].strip().lower()
if mode != "predict" and mode != "train":
    print("Mode is invalid, must be either 'train' or 'predict':", mode)
    sys.exit(1)
model_file = sys.argv[6]
bucket_suffix = sys.argv[7]

# Configure google storage bucket access
client = storage.Client.from_service_account_json('./credentials/credentials.json')
bucket = client.get_bucket("tf-models_" + bucket_suffix)


def decode_avro(message):
    schema = avro.schema.parse(open("cardata-v1.avsc").read())
    reader = DatumReader(schema)
    # you should decode bytes type to string type
    message = message.numpy()
    # remove kafka framing
    message_bytes = io.BytesIO(message[5:])
    decoder = BinaryDecoder(message_bytes)
    event_dict = reader.read(decoder)
    # output = event_dict.values()
    output = [event_dict[k] for k in event_dict.keys()]
    return output


def kafka_dataset(servers, topic, offset, eof=True, mode='train'):
    if mode == 'train':
        dataset = tfio.IODataset.from_kafka(topic, partition=0, offset=0, servers=servers, configuration=kafka_config)
        dataset = dataset.map(lambda x: tf.py_function(decode_avro, [x.message], [
            tf.float64,
            tf.float64,
            tf.float64,
            tf.float64,
            tf.float64,
            tf.float64,
            tf.float64,
            tf.float64,
            tf.float64,
            tf.int32,
            tf.int32,
            tf.int32,
            tf.int32,
            tf.float64,
            tf.float64,
            tf.float64,
            tf.float64,
            tf.int32,
            tf.string]))

    elif mode == 'predict':
        dataset = tfio.experimental.streaming.KafkaGroupIODataset(
            topics=[topic],
            group_id="cg-report-8",
            servers=servers,
            stream_timeout=30000,  # in milliseconds, to block indefinitely, set it to -1.
            configuration=[
                "session.timeout.ms=30000",
                "max.poll.interval.ms=30000",
                "auto.offset.reset=earliest",
                # "auto.offset.reset=latest",
                "enable.partition.eof=false"
            ],
        )
        dataset = dataset.map(lambda message, key: tf.py_function(decode_avro, [message], [
            tf.float64,
            tf.float64,
            tf.float64,
            tf.float64,
            tf.float64,
            tf.float64,
            tf.float64,
            tf.float64,
            tf.float64,
            tf.int32,
            tf.int32,
            tf.int32,
            tf.int32,
            tf.float64,
            tf.float64,
            tf.float64,
            tf.float64,
            tf.int32,
            tf.string]))

    return dataset


def normalize_fn(
        coolant_temp,
        intake_air_temp,
        intake_air_flow_speed,
        battery_percentage,
        battery_voltage,
        current_draw,
        speed,
        engine_vibration_amplitude,
        throttle_pos,
        tire_pressure_11,
        tire_pressure_12,
        tire_pressure_21,
        tire_pressure_22,
        accelerometer_11_value,
        accelerometer_12_value,
        accelerometer_21_value,
        accelerometer_22_value,
        control_unit_firmware,
        failure_occurred):
    tire_pressure_11 = tf.cast(tire_pressure_11, tf.float64)
    tire_pressure_12 = tf.cast(tire_pressure_12, tf.float64)
    tire_pressure_21 = tf.cast(tire_pressure_21, tf.float64)
    tire_pressure_22 = tf.cast(tire_pressure_22, tf.float64)

    control_unit_firmware = tf.cast(control_unit_firmware, tf.float64)

    def scale_fn(value, value_min, value_max):
        return (value - value_min) / (value_max - value_min) * 2.0 - 1.0

    coolant_temp = scale_fn(coolant_temp, 23.0, 102.0)

    # intake_air_temp (15, 40) => (-1.0, 1.0)
    intake_air_temp = scale_fn(intake_air_temp, 15.0, 40.0)

    intake_air_flow_speed = scale_fn(intake_air_flow_speed, 0.0, 200.0)

    # battery_percentage ?????????? (0, 100) => (-1.0, 1.0)
    battery_percentage = scale_fn(battery_percentage, 0.0, 100.0)

    battery_voltage = scale_fn(battery_voltage, 180.0, 260.0)

    current_draw = scale_fn(current_draw, 80.0, 84.0)

    # speed ?????????? (0, 50) => (-1.0, 1.0)
    speed = scale_fn(speed, 0.0, 50.0)

    # engine_vibration_amplitude ???? [speed * 150 or speed * 100] (0, 7500) => (-1.0. 1.0)
    engine_vibration_amplitude = scale_fn(engine_vibration_amplitude, 0.0, 7500.0)

    # throttle_pos (0, 1) => (-1.0, 1.0)
    throttle_pos = scale_fn(throttle_pos, 0.0, 1.0)

    # tire pressure (20, 35) => (-1.0, 1.0)
    tire_pressure_11 = scale_fn(tire_pressure_11, 20.0, 35.0)
    tire_pressure_12 = scale_fn(tire_pressure_12, 20.0, 35.0)
    tire_pressure_21 = scale_fn(tire_pressure_21, 20.0, 35.0)
    tire_pressure_22 = scale_fn(tire_pressure_22, 20.0, 35.0)

    # accelerometer (0, 7) => (-1.0, 1.0)
    accelerometer_11_value = scale_fn(accelerometer_11_value, 0.0, 7.0)
    accelerometer_12_value = scale_fn(accelerometer_12_value, 0.0, 7.0)
    accelerometer_21_value = scale_fn(accelerometer_21_value, 0.0, 7.0)
    accelerometer_22_value = scale_fn(accelerometer_22_value, 0.0, 7.0)

    # control_unit_firmware [1000|2000] => (-1.0, 1.0)
    control_unit_firmware = scale_fn(control_unit_firmware, 1000.0, 2000.0)

    return tf.stack([
        coolant_temp,
        intake_air_temp,
        intake_air_flow_speed,
        battery_percentage,
        battery_voltage,
        current_draw,
        speed,
        engine_vibration_amplitude,
        throttle_pos,
        tire_pressure_11,
        tire_pressure_12,
        tire_pressure_21,
        tire_pressure_22,
        accelerometer_11_value,
        accelerometer_12_value,
        accelerometer_21_value,
        accelerometer_22_value,
        control_unit_firmware]), failure_occurred


def _fixup_shape(x):
    x.set_shape([18])
    return x


# Note: same autoencoder, except:
# Autoencoder: 30 => 14 => 7 => 7 => 14 => 30 dimensions
# replaced by
# Autoencoder: 18 => 14 => 7 => 7 => 14 => 18 dimensions

nb_epoch = 100
batch_size = 1

# Autoencoder: 18 => 14 => 7 => 7 => 14 => 18 dimensions
input_dim = 18  # num of columns, 18
encoding_dim = 14
hidden_dim = int(encoding_dim / 2)  # i.e. 7
learning_rate = 1e-7

# Dense = fully connected layer
# Dense = fully connected layer
input_layer = tf.keras.layers.Input(shape=(input_dim,))
# First parameter is output units (14 then 7 then 7 then 30) :
encoder = tf.keras.layers.Dense(encoding_dim, activation="tanh",
                                activity_regularizer=tf.keras.regularizers.l1(learning_rate))(input_layer)
encoder = tf.keras.layers.Dense(hidden_dim, activation="relu")(encoder)
decoder = tf.keras.layers.Dense(hidden_dim, activation='tanh')(encoder)
decoder = tf.keras.layers.Dense(input_dim, activation='relu')(decoder)
autoencoder = tf.keras.models.Model(inputs=input_layer, outputs=decoder)

# create data for training
dataset = kafka_dataset(servers, topic, offset, mode=mode)

# normalize data
dataset = dataset.map(normalize_fn)

if mode == "train":
    autoencoder.compile(metrics=['accuracy'],
                        loss='mean_squared_error',
                        optimizer='adam')

    autoencoder.summary()
    # Let's keep a copy for later usage, and use dataset_training instead for training only

    # only take data from failure_occurred == false for normal case for training
    dataset = dataset.filter(lambda x, y: y == "false")

    # autoencoder is x => x so no y
    dataset = dataset.map(lambda x, y: x)


    def _fixup_shape(x):
        x.set_shape([18])
        return x


    dataset = dataset.map(_fixup_shape)

    # Autoencoder => Input == Output
    dataset_training = tf.data.Dataset.zip((dataset, dataset)).batch(batch_size)
    predictions = autoencoder.fit(dataset_training, epochs=nb_epoch, verbose=2)
    print("Training complete")

    # Save the model
    autoencoder.save("/" + model_file)

    # Store model into file:
    blob = bucket.blob("/" + model_file)
    blob.upload_from_filename("/" + model_file)
    print("Model stored successfully", model_file)


class OutputCallback(tf.keras.callbacks.Callback):
    """KafkaOutputCallback"""

    def __init__(self, batch_size, topic, servers):
        self.topic = topic
        # self._sequence = kafka_io.KafkaOutputSequence(
        #     topic=topic, servers=servers, configuration=kafka_config)
        self._sequence = KafkaProducer(bootstrap_servers=servers)
        self._batch_size = batch_size

    def on_predict_batch_end(self, batch, logs=None):
        index = batch * self._batch_size
        for outputs in logs['outputs']:
            message = np.array2string(outputs)
            self._sequence.send(self.topic, value=message.encode('utf-8'))
            # self._sequence.setitem(index, message)

    def flush(self):
        self._sequence.flush()


if mode == "predict":
    print("Downloading model", model_file)
    blob = bucket.blob("/" + model_file)
    blob.download_to_filename("/" + model_file)
    print("Loading model")
    # Recreate the exact same model purely from the file
    new_autoencoder = tf.keras.models.load_model("/" + model_file)
    output = OutputCallback(batch_size, result_topic, servers)

    dataset = dataset.filter(lambda x, y: y == "false")
    # autoencoder is x => x so no y
    dataset = dataset.map(lambda x, y: x)
    dataset = dataset.map(_fixup_shape)
    dataset = dataset.batch(batch_size)
    predict_out = new_autoencoder.predict(dataset, callbacks=[output])
    output.flush()
    print("Predict complete")