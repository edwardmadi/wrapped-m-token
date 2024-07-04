// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.23;

interface IMigratable {
    event Migrated(address indexed migrator, address indexed oldImplementation, address indexed newImplementation);

    event Upgraded(address indexed implementation);

    error InvalidMigrator();

    error ZeroMigrator();

    function migrate() external;

    function implementation() external view returns (address implementation);
}