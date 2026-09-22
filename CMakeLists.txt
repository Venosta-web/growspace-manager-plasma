cmake_minimum_required(VERSION 3.20)

project(growspace-manager-plasma-native LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)

find_package(Qt6 REQUIRED COMPONENTS Core Qml)
find_package(KF6Wallet REQUIRED)

add_library(growspacewalletplugin SHARED
    native/walletplugin.cpp
    native/walletstore.cpp
    native/walletstore.h
)

target_link_libraries(growspacewalletplugin
    PRIVATE
        Qt6::Core
        Qt6::Qml
        KF6::Wallet
)
