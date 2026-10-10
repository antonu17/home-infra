FROM python:3.13.7-alpine3.22@sha256:9ba6d8cbebf0fb6546ae71f2a1c14f6ffd2fdab83af7fa5669734ef30ad48844 AS build
RUN apk add --no-cache build-base linux-headers
COPY requirements.txt /tmp/requirements.txt
# netifaces 0.11.0 uses NULL for a musl integer padding field; newer GCC rejects it.
RUN CFLAGS="-Wno-error=int-conversion" pip install --no-cache-dir --require-hashes -r /tmp/requirements.txt

FROM python:3.13.7-alpine3.22@sha256:9ba6d8cbebf0fb6546ae71f2a1c14f6ffd2fdab83af7fa5669734ef30ad48844
COPY --from=build /usr/local/lib/python3.13/site-packages/ /usr/local/lib/python3.13/site-packages/
ADD https://raw.githubusercontent.com/alsmith/multicast-relay/461d1c97f3aaf0ab9f8996e1a8f24c6b8204d6b4/multicast-relay.py /app/multicast-relay.py
ADD https://raw.githubusercontent.com/alsmith/multicast-relay/461d1c97f3aaf0ab9f8996e1a8f24c6b8204d6b4/LICENSE /app/LICENSE
RUN echo "60bc9c3a96d980c0e8df7c677bf6c70dd66bce9276a708f20a8ee074a82af786  /app/multicast-relay.py" | sha256sum -c - \
 && echo "8ceb4b9ee5adedde47b31e975c1d90c73ad27b6b165a1dcd80c7c545eb65b903  /app/LICENSE" | sha256sum -c -
COPY entrypoint.py /app/entrypoint.py
ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1
ENTRYPOINT ["python3", "/app/entrypoint.py"]
