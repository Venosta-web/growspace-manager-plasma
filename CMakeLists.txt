cmake_minimum_required(VERSION 3.20)

project(growspace-manager-plasma-native LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)

find_package(Qt6 REQUIRED COMPONENTS Core Qml)
find_package(KF6 REQUIRED COMPONENTS Wallet)

set(GROWSPACE_QML_INSTALL_DIR "" CACHE PATH
    "Qt QML import root (normally reported by: qtpaths6 --query QT_INSTALL_QML)")

if(NOT GROWSPACE_QML_INSTALL_DIR)
    message(FATAL_ERROR "GROWSPACE_QML_INSTALL_DIR is required")
endif()

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

install(
    TARGETS growspacewalletplugin
    LIBRARY DESTINATION "${GROWSPACE_QML_INSTALL_DIR}/com/venosta/growspacewallet"
)

install(
    FILES native/qmldir
    DESTINATION "${GROWSPACE_QML_INSTALL_DIR}/com/venosta/growspacewallet"
)
