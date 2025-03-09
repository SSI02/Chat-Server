#include <iostream>
#include <thread>
#include <unordered_map>
#include <unordered_set>
#include <vector>
#include <string>
#include <mutex>
#include <fstream>
#include <sstream>
#include <netinet/in.h>
#include <unistd.h>
#include <cstring>
#include <arpa/inet.h>

#define PORT 12345
#define BUFFER_SIZE 1024

// Separate mutexes for better concurrency
std::mutex clients_mutex;
std::mutex groups_mutex;

// Data structures
std::unordered_map<std::string, std::string> users;                  // Username -> Password
std::unordered_map<int, std::string> clients;                        // Socket -> Username
std::unordered_map<std::string, std::unordered_set<int>> groups;    // Group -> Client sockets

// Helper function to trim whitespace
std::string trim(const std::string& str) {
    auto start = str.find_first_not_of(" \n\r\t");
    auto end = str.find_last_not_of(" \n\r\t");
    return (start == std::string::npos || end == std::string::npos) ? "" : str.substr(start, end - start + 1);
}

// Load user credentials from file
void load_users(const std::string& filename) {
    std::ifstream file(filename);
    if (!file.is_open()) {
        std::cerr << "Error opening users file: " << filename << std::endl;
        exit(1);
    }

    std::string line;
    while (std::getline(file, line)) {
        size_t delimiter = line.find(':');
        if (delimiter != std::string::npos) {
            std::string username = trim(line.substr(0, delimiter));
            std::string password = trim(line.substr(delimiter + 1));
            users[username] = password;
        }
    }
    file.close();
}

// Send message to a specific client
void send_message(int client_socket, const std::string& message) {
    if (send(client_socket, message.c_str(), message.size(), 0) == -1) {
        std::cerr << "Failed to send message to socket " << client_socket << std::endl;
    }
}

// Broadcast message to all clients except sender
void broadcast_message(const std::string& message, int sender_socket) {
    std::lock_guard<std::mutex> lock(clients_mutex);
    for (const auto& [socket, username] : clients) {
        if (socket != sender_socket) {
            send_message(socket,"[Broadcast from " + clients[sender_socket] + "]: " + message);
        }
    }
}

// Send private message to a specific user
void private_message(int sender_socket, const std::string& recipient, const std::string& message) {
    std::lock_guard<std::mutex> lock(clients_mutex);
    bool found = false;
    for (const auto& [socket, username] : clients) {
        if (username == recipient) {
            send_message(socket, clients[sender_socket] + ": " + message);
            // send_message(sender_socket, "[Private to " + recipient + "]: " + message);
            found = true;
            break;
        }
    }
    if (!found) {
        send_message(sender_socket, "Error: User '" + recipient + "' not found.");
    }
}

// Send message to a group
void group_message(int sender_socket, const std::string& group_name, const std::string& message) {
    std::lock_guard<std::mutex> lock(groups_mutex);
    if (groups.find(group_name) == groups.end()) {
        send_message(sender_socket, "Error: Group '" + group_name + "' does not exist.");
        return;
    }

    if (groups[group_name].find(sender_socket) == groups[group_name].end()) {
        send_message(sender_socket, "Error: You are not a member of group '" + group_name + "'.");
        return;
    }

    std::string sender_name = clients[sender_socket];
    for (int socket : groups[group_name]) {
        if (socket != sender_socket) {
            send_message(socket, "[Group: " + group_name + "]" + ": " + message);
        }
    }
    // send_message(sender_socket, "[Group: " + group_name + "] You: " + message);
}

// Remove client from server
void remove_client(int client_socket) {
    std::string username;
    {
        std::lock_guard<std::mutex> lock_clients(clients_mutex);
        if (clients.find(client_socket) != clients.end()) {
            username = clients[client_socket];
            clients.erase(client_socket);
        }
    }

    if (!username.empty()) {
        std::lock_guard<std::mutex> lock_groups(groups_mutex);
        // Remove from all groups
        for (auto& group : groups) {
            group.second.erase(client_socket);
        }
        // Broadcast departure
        for (const auto& [socket, username1] : clients) {
            if (socket != client_socket) {
                send_message(socket, username + " has left the chat.");
            }
        }
    }
    
    close(client_socket);
}

// Handle client connection
void handle_client(int client_socket) {
    char buffer[BUFFER_SIZE];
    std::string username;

    // Authentication
    send_message(client_socket, "Enter username: ");
    memset(buffer, 0, BUFFER_SIZE);
    int bytes_received = recv(client_socket, buffer, BUFFER_SIZE, 0);
    if (bytes_received <= 0) {
        close(client_socket);
        return;
    }
    username = trim(buffer);

    send_message(client_socket, "Enter password: ");
    memset(buffer, 0, BUFFER_SIZE);
    bytes_received = recv(client_socket, buffer, BUFFER_SIZE, 0);
    if (bytes_received <= 0) {
        close(client_socket);
        return;
    }
    std::string password = trim(buffer);

    // Validate credentials
    if (users.find(username) == users.end() || users[username] != password) {
        send_message(client_socket, "Authentication failed.\n");
        close(client_socket);
        return;
    }

    // Check for duplicate login
    {
        std::lock_guard<std::mutex> lock(clients_mutex);
        for (const auto& client : clients) {
            if (client.second == username) {
                send_message(client_socket, "Error: User already logged in.\n");
                close(client_socket);
                return;
            }
        }
        clients[client_socket] = username;
    }

    // send_message(client_socket, "Welcome to the chat server, " + username + "!\n");
    send_message(client_socket, "Welcome to the chat server!\n");
    // send_message(client_socket, "Available commands:\n"
    //                            "/broadcast <message> - Send message to all users\n"
    //                            "/msg <username> <message> - Send private message\n"
    //                            "/create_group <group_name> - Create a new group\n"
    //                            "/join_group <group_name> - Join an existing group\n"
    //                            "/leave_group <group_name> - Leave a group\n"
    //                            "/group_msg <group_name> <message> - Send message to group\n"
    //                            "/exit - Disconnect from server\n");
    for (const auto& [socket, username] : clients) {
        if (socket != client_socket) {
            send_message(socket, clients[client_socket] + " has joined the chat.");
        }
    }

    while (true) {
        memset(buffer, 0, BUFFER_SIZE);
        bytes_received = recv(client_socket, buffer, BUFFER_SIZE, 0);

        if (bytes_received <= 0) {
            remove_client(client_socket);
            return;
        }

        std::string message(buffer, bytes_received);
        message = trim(message);
        // std::string message = trim(buffer);
        
        if (message.empty()) continue;

        if (message == "/exit") {
            remove_client(client_socket);
            return;
        }
        else if (message.starts_with("/broadcast ")) {
            broadcast_message(message.substr(10), client_socket);
        }
        else if (message.starts_with("/msg ")) {
            size_t first_space = message.find(' ', 5);
            if (first_space != std::string::npos) {
                std::string recipient = message.substr(5, first_space - 5);
                std::string private_msg = message.substr(first_space + 1);
                private_message(client_socket, recipient, private_msg);
            } else {
                send_message(client_socket, "Error: Invalid format. Use /msg <username> <message>");
            }
        }
        else if (message.starts_with("/create_group ")) {
            std::string group_name = message.substr(14);
            std::lock_guard<std::mutex> lock(groups_mutex);
            if (groups.find(group_name) != groups.end()) {
                send_message(client_socket, "Error: Group '" + group_name + "' already exists.");
            } else {
                groups[group_name].insert(client_socket);
                send_message(client_socket, "Group '" + group_name + "' created.");
            }
        }
        else if (message.starts_with("/join_group ")) {
            std::string group_name = message.substr(12);
            std::lock_guard<std::mutex> lock(groups_mutex);
            if (groups.find(group_name) == groups.end()) {
                send_message(client_socket, "Error: Group '" + group_name + "' does not exist.");
            } else {
                groups[group_name].insert(client_socket);
                send_message(client_socket, "You joined the group " + group_name + ".");
            }
        }
        else if (message.starts_with("/leave_group ")) {
            std::string group_name = message.substr(13);
            std::lock_guard<std::mutex> lock(groups_mutex);
            if (groups.find(group_name) != groups.end()) {
                if (groups[group_name].erase(client_socket) > 0) {
                    send_message(client_socket, "You left the group " + group_name + ".");
                } else {
                    send_message(client_socket, "Error: You are not a member of group '" + group_name + "'.");
                }
            } else {
                send_message(client_socket, "Error: Group '" + group_name + "' does not exist.");
            }
        }
        else if (message.starts_with("/group_msg ")) {
            size_t first_space = message.find(' ', 11);
            if (first_space != std::string::npos) {
                std::string group_name = message.substr(11, first_space - 11);
                std::string group_msg = message.substr(first_space + 1);
                group_message(client_socket, group_name, group_msg);
            } else {
                send_message(client_socket, "Error: Invalid format. Use /group_msg <group_name> <message>");
            }
        }
        else {
            send_message(client_socket, "Error: Unknown command.");
        }
    }
}

int main() {
    int server_socket;
    struct sockaddr_in server_addr;

    // Load user credentials
    load_users("users.txt");

    // Create socket
    server_socket = socket(AF_INET, SOCK_STREAM, 0);
    if (server_socket == -1) {
        std::cerr << "Error: Failed to create socket." << std::endl;
        return 1;
    }

    // Set socket options
    int opt = 1;
    if (setsockopt(server_socket, SOL_SOCKET, SO_REUSEADDR, &opt, sizeof(opt)) < 0) {
        std::cerr << "Error: Failed to set socket options." << std::endl;
        return 1;
    }

    // Configure server address
    server_addr.sin_family = AF_INET;
    server_addr.sin_addr.s_addr = INADDR_ANY;
    server_addr.sin_port = htons(PORT);

    // Bind socket
    if (bind(server_socket, (struct sockaddr*)&server_addr, sizeof(server_addr)) == -1) {
        std::cerr << "Error: Binding failed." << std::endl;
        return 1;
    }

    // Listen for connections
    if (listen(server_socket, 10) == -1) {
        std::cerr << "Error: Failed to listen." << std::endl;
        return 1;
    }

    // std::cout << "Server started on port " << PORT << std::endl;
    // std::cout << "Waiting for connections..." << std::endl;

    // Accept client connections
    while (true) {
        struct sockaddr_in client_addr;
        socklen_t client_len = sizeof(client_addr);
        
        int client_socket = accept(server_socket, (struct sockaddr*)&client_addr, &client_len);
        if (client_socket == -1) {
            std::cerr << "Error: Failed to accept connection." << std::endl;
            continue;
        }

        std::cout << "New connection from " << inet_ntoa(client_addr.sin_addr) << ":" 
                  << ntohs(client_addr.sin_port) << std::endl;

        std::thread(handle_client, client_socket).detach();
    }

    close(server_socket);
    return 0;
}