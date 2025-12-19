pluginManagement {
    repositories {
        google {
            content {
                includeGroupByRegex("com\\.android.*")
                includeGroupByRegex("com\\.google.*")
                includeGroupByRegex("androidx.*")
            }
        }
        mavenCentral()
        gradlePluginPortal()
    }
}
dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories {
        google()
        mavenCentral()
    }
}

rootProject.name = "HERESDKUnitsKotlin"
include(":app")
include(":here-sdk-units-core")
include(":here-sdk-units-mapswitcher")
include(":here-sdk-units-popupmenu")
include(":here-sdk-units-compass")
include(":here-sdk-units-mapruler")
include(":here-sdk-units-speedlimit")
