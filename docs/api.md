# API Reference

<!-- 
  This file is maintained by agents during development.
  Every new endpoint must be documented here in the same PR that implements it.
  Format: one table per resource, ordered by method (GET before POST before PUT before DELETE).
-->

## Status

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| GET | `/health` | None | Health check — returns `{"status": "ok"}` |

<!--
## [Resource Name]

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| GET    | `/resource`     | Bearer | List all resources |
| POST   | `/resource`     | Bearer | Create a new resource |
| GET    | `/resource/:id` | Bearer | Get a single resource |
| PUT    | `/resource/:id` | Bearer | Update a resource |
| DELETE | `/resource/:id` | Bearer | Delete a resource |

### POST `/resource` — Request body

```json
{
  "field": "string",
  "other_field": 0
}
```

### POST `/resource` — Response

```json
{
  "id": "uuid",
  "field": "string",
  "created_at": "ISO8601"
}
```

### Error responses

| Code | When |
|------|------|
| 400  | Invalid request body |
| 401  | Missing or expired token |
| 404  | Resource not found |
| 422  | Validation error |
-->
