import socket, select, struct, sys, threading

def forward(src, dst):
    try:
        while True:
            r, _, _ = select.select([src, dst], [], [])
            for s in r:
                data = s.recv(8192)
                if not data: return
                if s is src: dst.sendall(data)
                else: src.sendall(data)
    except Exception: pass

def handle_client(client, remote_ip, remote_port):
    try:
        proxy = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        proxy.connect(("127.0.0.1", 1055)) # Tailscale SOCKS5 port
        proxy.sendall(b"\x05\x01\x00")
        if proxy.recv(2) != b"\x05\x00": return
        
        req = b"\x05\x01\x00\x01" + socket.inet_aton(remote_ip) + struct.pack(">H", remote_port)
        proxy.sendall(req)
        resp = proxy.recv(10)
        if resp[1] != 0: return
        
        forward(client, proxy)
    finally:
        client.close()

if __name__ == "__main__":
    server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    
    # Listen on localhost:20129
    server.bind(("127.0.0.1", 20129))
    server.listen(5)
    print("🚀 Nest 2.0 Tunnel active! Listening on 127.0.0.1:20129 -> 100.123.6.86:20129 via SOCKS5")
    
    while True:
        client, _ = server.accept()
        threading.Thread(target=handle_client, args=(client, "100.123.6.86", 20129), daemon=True).start()
