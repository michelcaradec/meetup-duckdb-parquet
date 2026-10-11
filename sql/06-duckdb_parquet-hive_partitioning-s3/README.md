# DuckDB & Parquet - Object Storage Demonstration

1. Start the local object storage service [VaultS3](https://www.vaults3.com/):

    ```bash
    cd vaults3
    docker compose up -d
    cd -
    ```

2. Navigate to <http://localhost:9999/dashboard/buckets>.

> [!TIP]
> The credentials are stored in the file [vaults3.env](../../vaults3/vaults3.env).

3. Create a **bucket** named `parquet-demo`.
4. Navigate to <http://localhost:9999/dashboard/access-keys>.
5. Create an **access key** with bucket access on `parquet-demo`.
6. Copy the access key and the secret to the file [.env](.env) (copy of the template file [.env.default](.env.default)):

    ```bash
    S3_KEY_ID=******
    S3_SECRET=******
    ```

7. Optional: "man in the middle" proxy:

   1. Set the environment variable `S3_HTTP_PROXY` (file [.env](.env)) to the URL of a "man in the middle" proxy (use `http://localhost:8080` with [mitmproxy](https://www.mitmproxy.org/)):  
        This will allow to intercept the requests sent by DuckDB to the object storage service.

        ```bash
        S3_HTTP_PROXY=http://localhost:8080
        ```

   2. Run the "man in the middle proxy":

        ```bash
        mitmproxy
        ```

> [!TIP]
> The mitmproxy [web interface](https://www.mitmproxy.org/#mitmweb) can also be executed:
>
> ```bash
> mitmweb
> ```

8. Run the SQL script:

    ```bash
    bash ./sql/06-duckdb_parquet-hive_partitioning-s3/duckdb_parquet-hive_partitioning-s3.sh
    ```

> [!IMPORTANT]
> Be sure to be located at the project root folder.

9. Optional: check in the "man in the middle" proxy the **HTTP range requests** and the [206 Partial Content](https://developer.mozilla.org/en-US/docs/Web/HTTP/Reference/Status/206) responses.

    ```raw
    18:41:14 HTTP  GET  localhost /parquet-demo/?encoding-type=url&list-type=2&prefix=penguins%2F  200 application/xml 16.5k  10ms 
    18:41:14 HTTP  GET  localhost /parquet-demo/penguins/year%3D2020/month%3D1/data_0.parquet      206 …n/octet-stream  3.5k   7ms 
    18:41:14 HTTP  GET  localhost /parquet-demo/penguins/year%3D2023/month%3D3/data_0.parquet      206 …n/octet-stream  3.5k   7ms 
    18:41:14 HTTP  GET  localhost /parquet-demo/penguins/year%3D2023/month%3D3/data_0.parquet      206 …n/octet-stream  2.4k   6ms 
    ```

    The HTTP range requests are done to access the columns `species` and `body_mass_g` (projection pushdown), located in the candidate row groups (predicate pushdown).
