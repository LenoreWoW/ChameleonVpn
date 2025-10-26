# BarqNet API Quick Reference Guide

## Endpoint Summary

| Method | Endpoint | Description | Auth Required |
|--------|----------|-------------|---------------|
| POST | `/vpn/status` | Update connection status | Yes (JWT) |
| POST | `/vpn/stats` | Upload usage statistics | Yes (JWT) |
| GET | `/vpn/stats/{username}` | Get user statistics | Yes (JWT) |
| GET | `/vpn/locations` | List server locations | Yes (JWT) |
| GET | `/vpn/locations/{id}/servers` | Get servers in location | Yes (JWT) |
| GET | `/vpn/config?username=X` | Get VPN configuration | Yes (JWT) |

## Quick Test Commands

### 1. Update Status
```bash
curl -X POST http://localhost:8080/vpn/status \
  -H "Authorization: Bearer TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"status":"connected","server_id":"server-1","ip_address":"192.168.1.100"}'
```

### 2. Upload Stats
```bash
curl -X POST http://localhost:8080/vpn/stats \
  -H "Authorization: Bearer TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"server_id":"server-1","bytes_in":1048576,"bytes_out":524288,"duration_seconds":3600}'
```

### 3. Get User Stats
```bash
curl "http://localhost:8080/vpn/stats/john_doe?username=john_doe" \
  -H "Authorization: Bearer TOKEN"
```

### 4. List Locations
```bash
curl "http://localhost:8080/vpn/locations?username=john_doe" \
  -H "Authorization: Bearer TOKEN"
```

### 5. Get Location Servers
```bash
curl "http://localhost:8080/vpn/locations/1/servers?username=john_doe" \
  -H "Authorization: Bearer TOKEN"
```

### 6. Get Config
```bash
curl "http://localhost:8080/vpn/config?username=john_doe" \
  -H "Authorization: Bearer TOKEN"
```

## Database Tables

### vpn_connections
- Tracks connection events (connect/disconnect)
- Fields: username, status, server_id, timestamps, ip_address

### vpn_statistics
- Stores usage data per session
- Fields: username, server_id, bytes_in, bytes_out, duration_seconds

### server_locations
- Geographic server locations
- Fields: country, city, country_code, lat/long, enabled

## Common Response Codes

- **200 OK** - Success
- **400 Bad Request** - Invalid input
- **401 Unauthorized** - Missing/invalid JWT
- **403 Forbidden** - Insufficient permissions
- **404 Not Found** - Resource not found
- **500 Internal Server Error** - Server error

## Status Values

Valid status values for `/vpn/status`:
- `connected` - Successfully connected
- `disconnected` - Disconnected from VPN
- `connecting` - Connection in progress
- `error` - Connection failed

## Implementation Files

```
/Users/hassanalsahli/Desktop/ChameleonVpn/barqnet-backend/apps/management/api/
├── stats.go              # Statistics endpoints (380 lines)
├── locations.go          # Locations endpoints (433 lines)
├── config.go             # Configuration endpoint (352 lines)
├── VPN_API_DOCUMENTATION.md     # Full API docs
├── IMPLEMENTATION_SUMMARY.md    # Implementation details
└── QUICK_REFERENCE.md           # This file
```

## Server Selection Logic

When calling `/vpn/config`:
1. Checks user's preferred server
2. If load < 80%, uses preferred server
3. Otherwise, selects least-loaded server
4. Returns OVPN content + recommendations

## Security Notes

- All endpoints require JWT Bearer token
- Users can only access their own data (except admins)
- All actions are audit logged
- Input validation on all endpoints
- Rate limiting via middleware

## Next Steps

1. **Implement JWT**: Replace placeholder with actual JWT validation
2. **Test Endpoints**: Use provided cURL commands
3. **Add Sample Data**: Insert test locations into server_locations table
4. **Configure Servers**: Link servers to locations via location_id
5. **Monitor Logs**: Check audit_log table for API activity

## Sample Location Data

```sql
INSERT INTO server_locations (country, city, country_code, latitude, longitude, enabled)
VALUES
  ('United States', 'New York', 'US', 40.7128, -74.0060, true),
  ('United Kingdom', 'London', 'GB', 51.5074, -0.1278, true),
  ('Singapore', 'Singapore', 'SG', 1.3521, 103.8198, true),
  ('Germany', 'Frankfurt', 'DE', 50.1109, 8.6821, true);

-- Link a server to a location
UPDATE servers SET location_id = 1 WHERE name = 'server-us-ny-1';
```

## Troubleshooting

**401 Unauthorized**
- Check JWT token in Authorization header
- Verify token format: `Bearer <token>`
- Add `?username=X` for testing

**403 Forbidden**
- User trying to access other user's data
- Check admin privileges
- Verify user account is active

**500 Internal Server Error**
- Check database connection
- Verify tables exist (run migrations)
- Check server logs for details

## API Testing with Postman

1. Set Authorization header: `Bearer <token>`
2. For testing, add query param: `?username=testuser`
3. Set Content-Type: `application/json`
4. Import endpoints from documentation

## Performance Tips

- Server locations are cached (sample data)
- Statistics queries are indexed
- Connection history limited to 50 recent
- Health checks run every 30 seconds

## Support

For detailed documentation, see:
- `VPN_API_DOCUMENTATION.md` - Complete API reference
- `IMPLEMENTATION_SUMMARY.md` - Technical implementation details
