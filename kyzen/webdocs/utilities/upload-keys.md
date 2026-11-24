# UploadKeysService

Upload newly found decryption keys to the key server database.

## Safety & Upload Filtering

- **Blacklist Filtering:** Prevents standard skin pack keys (e.g. `s5s5ejuDru4uchuF2drUFuthaspAbepE`) from being sent to the server.
- **Duplicate Filtering:** Compares keys to be sent with the local cached `keys.tsv` database. Filters out keys that have already been cataloged.

## Upload JSON API Payload

```json
[
  {
    "friendlyid": "c92ddd9b-0134-49d8-9425-ffd4f6267367",
    "contentkey": "pF0IQfnz9ygTkGmceuRLiRxJmb0hw0oh"
  }
]
```
