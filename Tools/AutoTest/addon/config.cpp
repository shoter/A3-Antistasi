// Antistasi automated test harness. Packed and loaded only by Tools\AutoTest\launch_tests.ps1, never shipped.
// Maintainer: Shoter

class CfgPatches {
    class A3A_autotest {
        name = "Antistasi automated tests";
        units[] = {};
        weapons[] = {};
        requiredVersion = 2.0;
        requiredAddons[] = {"A3A_core", "A3A_maps"};
        author = "Shoter";
    };
};

class CfgFunctions {
    class A3A_test {
        class main {
            file = "x\A3A_autotest\functions";
            class postInit { postInit = 1; };
            class log {};
            class startCampaign {};
            class defaultFactions {};
            class runTests {};
            class assert {};
            class assertEqual {};
            class fail {};
            class info {};
            class waitUntil {};
        };
    };
};
