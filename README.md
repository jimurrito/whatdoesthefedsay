# What Does the Fed(eral Reserve) Say?

A simple REST API that provides the current effective federal funds interest rate, sourced directly from the Federal Reserve's H.15 release.

> **Data Source:** [https://www.federalreserve.gov/releases/h15/](https://www.federalreserve.gov/releases/h15/)  
> **GitHub Repo:** [jimurrito/whatdoesthefedsay](https://github.com/jimurrito/whatdoesthefedsay)

---

## Usage

No authentication or API token required. Send a GET request to:

```
GET http://whatdoesthefedsay.com/rate
```

### Response

Returns a JSON body (~700–800 bytes):

```json
{
    "rate": "5.33",
    "seed": 442595821,
    "date": "2024-Jun-7",
    "source": "https://www.federalreserve.gov/releases/h15/"
}
```

| Field    | Type    | Description                                  |
|----------|---------|----------------------------------------------|
| `rate`   | string  | Current effective federal funds rate (%)     |
| `date`   | string  | Date the rate became effective               |
| `seed`   | integer | Random nonce generated at update time        |
| `source` | string  | Data source URL                              |

---

*Rate values are updated in line with Federal Reserve publications.*