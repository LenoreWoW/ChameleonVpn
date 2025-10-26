# VPN Manager Web UI

A modern, responsive web interface for testing and managing the VPN Manager system.

## 🚀 Quick Start

### Option 1: Python Server (Recommended)
```bash
# Navigate to web-ui directory
cd /Users/wolf/vpnmanager/web-ui

# Start the server
python3 server.py
```

### Option 2: Simple HTTP Server
```bash
# Navigate to web-ui directory
cd /Users/wolf/vpnmanager/web-ui

# Start simple HTTP server
python3 -m http.server 3000
```

### Option 3: Any Web Server
```bash
# Copy the files to any web server
cp -r /Users/wolf/vpnmanager/web-ui/* /var/www/html/
```

## 🌐 Access the Interface

Once the server is running, open your browser and go to:
- **Local**: http://localhost:3000
- **Network**: http://your-server-ip:3000

## 🔧 Configuration

### Management Server Settings
1. **Management Server URL**: `http://192.168.10.248:8080` (default)
2. **API Key**: Enter your VPN Manager API key
3. **Server ID**: `endnode-1` (default)

### Custom Configuration
You can modify the default values in the web interface or edit the HTML file directly.

## 📋 Features

### 🏥 Health Check
- **System Health**: Check if management server is running
- **API Info**: Get list of available API endpoints
- **Real-time Status**: Monitor server health

### 👥 User Management
- **List Users**: View all users in the system
- **Create User**: Add new VPN users
- **Delete User**: Remove users from the system
- **User Details**: View user information and settings

### 🖥️ End-Node Management
- **List End-Nodes**: View all registered end-nodes
- **Register End-Node**: Add new end-nodes to the system
- **Health Check**: Send health checks to end-nodes
- **Status Monitoring**: Monitor end-node status

### 🔄 User Synchronization
- **Sync Users**: Synchronize users across end-nodes
- **Action Types**: Create, Update, Delete operations
- **Bulk Operations**: Sync multiple users at once

### 📊 System Logs
- **Recent Logs**: View system activity
- **Error Tracking**: Monitor system errors
- **Audit Trail**: Track user actions

## 🎨 Interface Features

### Modern Design
- **Responsive Layout**: Works on desktop, tablet, and mobile
- **Tabbed Interface**: Organized by functionality
- **Real-time Updates**: Live status and health monitoring
- **Error Handling**: Clear error messages and troubleshooting

### User Experience
- **One-Click Operations**: Simple buttons for common tasks
- **Form Validation**: Input validation and error checking
- **Loading Indicators**: Visual feedback during operations
- **JSON Response Viewer**: Formatted API responses

## 🔧 API Integration

The web interface uses the VPN Manager REST API:

### Base Endpoints
- `GET /health` - Health check
- `GET /api` - API information
- `GET /api/users` - List users
- `POST /api/users` - Create user
- `DELETE /api/users/{username}` - Delete user
- `GET /api/endnodes` - List end-nodes
- `POST /api/endnodes/register` - Register end-node
- `POST /api/users/sync` - Sync user

### Authentication
All API calls (except health check) require the API key:
```
Authorization: Bearer YOUR_API_KEY
```

## 🛠️ Development

### File Structure
```
web-ui/
├── index.html          # Main web interface
├── server.py           # Python HTTP server
└── README.md           # This file
```

### Customization
- **Styling**: Modify CSS in the `<style>` section
- **Functionality**: Add JavaScript functions
- **API Endpoints**: Update the `makeRequest()` function
- **UI Layout**: Modify HTML structure

### Adding New Features
1. **Add Tab**: Create new tab in HTML
2. **Add Functions**: Create JavaScript functions
3. **Add API Calls**: Use the `makeRequest()` helper
4. **Add UI Elements**: Create forms and buttons

## 🐛 Troubleshooting

### Common Issues

#### Server Won't Start
```bash
# Check if port is in use
netstat -tlnp | grep 3000

# Try different port
python3 server.py
# Edit PORT variable in server.py
```

#### API Connection Failed
- Check management server URL
- Verify API key is correct
- Ensure management server is running
- Check firewall settings

#### CORS Errors
- The server includes CORS headers
- If issues persist, check browser console
- Ensure management server allows cross-origin requests

### Debug Mode
Open browser developer tools (F12) to see:
- Network requests and responses
- JavaScript errors
- Console logs

## 📱 Mobile Support

The interface is responsive and works on:
- **Desktop**: Full feature set
- **Tablet**: Optimized layout
- **Mobile**: Touch-friendly interface

## 🔒 Security Notes

- **API Key**: Store securely, don't commit to version control
- **HTTPS**: Use HTTPS in production environments
- **Authentication**: Implement proper authentication for production
- **CORS**: Configure CORS properly for production

## 🚀 Production Deployment

### Nginx Configuration
```nginx
server {
    listen 80;
    server_name vpnmanager-ui.example.com;
    
    location / {
        root /path/to/web-ui;
        index index.html;
        try_files $uri $uri/ =404;
    }
}
```

### Apache Configuration
```apache
<VirtualHost *:80>
    ServerName vpnmanager-ui.example.com
    DocumentRoot /path/to/web-ui
    
    <Directory /path/to/web-ui>
        AllowOverride All
        Require all granted
    </Directory>
</VirtualHost>
```

## 📞 Support

For issues with the web interface:
1. Check browser console for errors
2. Verify management server is running
3. Test API endpoints directly with curl
4. Check network connectivity

## 🎯 Next Steps

1. **Start the server**: `python3 server.py`
2. **Open browser**: http://localhost:3000
3. **Configure settings**: Enter your API key
4. **Test functionality**: Try the health check
5. **Create users**: Add your first VPN user
6. **Register end-nodes**: Set up your VPN servers
