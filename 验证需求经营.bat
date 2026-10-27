@echo off
setlocal EnableExtensions
set "NEEDS_ROOT=%~dp0"
set "NEEDS_ENGINE=D:\tools\Godot-4.7.2\Godot_v4.7.2-stable_win64_console.exe"
set "APPDATA=%NEEDS_ROOT%.godot-user\AppData\Roaming"
set "LOCALAPPDATA=%NEEDS_ROOT%.godot-user\AppData\Local"
set "TEMP=%NEEDS_ROOT%.godot-user\Temp"
set "TMP=%TEMP%"
if not exist "%NEEDS_ENGINE%" exit /b 1
if not exist "%APPDATA%" mkdir "%APPDATA%"
if not exist "%LOCALAPPDATA%" mkdir "%LOCALAPPDATA%"
if not exist "%TEMP%" mkdir "%TEMP%"
if not exist "%NEEDS_ROOT%.godot-user\Logs" mkdir "%NEEDS_ROOT%.godot-user\Logs"
"D:\tools\python\python.exe" "%NEEDS_ROOT%tools\build_balance_v4.py" --check
if errorlevel 1 exit /b 1
"%NEEDS_ENGINE%" --headless --path "%NEEDS_ROOT%." --script res://qa/BalanceV4Acceptance.gd --log-file "%NEEDS_ROOT%.godot-user\Logs\balance-v4.log"
if errorlevel 1 exit /b 1
"%NEEDS_ENGINE%" --headless --path "%NEEDS_ROOT%." --script res://qa/InitialCapacityAcceptance.gd --log-file "%NEEDS_ROOT%.godot-user\Logs\initial-capacity.log"
if errorlevel 1 exit /b 1
"%NEEDS_ENGINE%" --headless --path "%NEEDS_ROOT%." --script res://qa/HouseUpgradeEffectsAcceptance.gd --log-file "%NEEDS_ROOT%.godot-user\Logs\house-upgrade-effects.log"
if errorlevel 1 exit /b 1
"%NEEDS_ENGINE%" --headless --path "%NEEDS_ROOT%." --script res://qa/PopulationShortageFeedbackAcceptance.gd --log-file "%NEEDS_ROOT%.godot-user\Logs\population-shortage-feedback.log"
if errorlevel 1 exit /b 1
"%NEEDS_ENGINE%" --headless --path "%NEEDS_ROOT%." --script res://qa/PopulationFailureAcceptance.gd --log-file "%NEEDS_ROOT%.godot-user\Logs\population-failure.log"
if errorlevel 1 exit /b 1
"%NEEDS_ENGINE%" --headless --path "%NEEDS_ROOT%." --script res://qa/WeaverConstructionResourceAcceptance.gd --log-file "%NEEDS_ROOT%.godot-user\Logs\weaver-construction-resource.log"
if errorlevel 1 exit /b 1
"%NEEDS_ENGINE%" --headless --path "%NEEDS_ROOT%." --script res://qa/ConstructionMaterialsAcceptance.gd --log-file "%NEEDS_ROOT%.godot-user\Logs\construction-materials.log"
if errorlevel 1 exit /b 1
"%NEEDS_ENGINE%" --headless --path "%NEEDS_ROOT%." --script res://qa/WeaverShortageUiAcceptance.gd --log-file "%NEEDS_ROOT%.godot-user\Logs\weaver-shortage-ui.log"
if errorlevel 1 exit /b 1
"%NEEDS_ENGINE%" --headless --path "%NEEDS_ROOT%." --script res://qa/RoadSurfaceVisualAcceptance.gd --log-file "%NEEDS_ROOT%.godot-user\Logs\road-surface.log"
if errorlevel 1 exit /b 1
"%NEEDS_ENGINE%" --headless --path "%NEEDS_ROOT%." --script res://qa/SettlementEconomyAcceptance.gd --log-file "%NEEDS_ROOT%.godot-user\Logs\needs-model.log"
if errorlevel 1 exit /b 1
"%NEEDS_ENGINE%" --headless --path "%NEEDS_ROOT%." --script res://qa/WaterClothingAcceptance.gd --log-file "%NEEDS_ROOT%.godot-user\Logs\water-clothing.log"
if errorlevel 1 exit /b 1
"%NEEDS_ENGINE%" --headless --path "%NEEDS_ROOT%." --script res://qa/ClothingLifecycleAcceptance.gd --log-file "%NEEDS_ROOT%.godot-user\Logs\clothing-lifecycle.log"
if errorlevel 1 exit /b 1
"%NEEDS_ENGINE%" --headless --path "%NEEDS_ROOT%." --script res://qa/NecessityHappinessAcceptance.gd --log-file "%NEEDS_ROOT%.godot-user\Logs\necessity-happiness.log"
if errorlevel 1 exit /b 1
"%NEEDS_ENGINE%" --headless --path "%NEEDS_ROOT%." --script res://qa/BuildingNetResourceUiAcceptance.gd --log-file "%NEEDS_ROOT%.godot-user\Logs\building-net-resources.log"
if errorlevel 1 exit /b 1
"%NEEDS_ENGINE%" --headless --path "%NEEDS_ROOT%." --script res://qa/ResourceStatusTooltipAcceptance.gd --log-file "%NEEDS_ROOT%.godot-user\Logs\resource-tooltip.log"
if errorlevel 1 exit /b 1
"%NEEDS_ENGINE%" --headless --path "%NEEDS_ROOT%." --script res://qa/NeedsEconomyIntegrationAcceptance.gd --log-file "%NEEDS_ROOT%.godot-user\Logs\needs-integration.log"
if errorlevel 1 exit /b 1
"%NEEDS_ENGINE%" --headless --path "%NEEDS_ROOT%." --script res://qa/FullCampaignAcceptance.gd --log-file "%NEEDS_ROOT%.godot-user\Logs\full-campaign-self-sufficient-no-trade.log" -- --strategy=self_sufficient
if errorlevel 1 exit /b 1
echo Economy, integration and self-sufficient no-trade campaign passed. Player saves were not used.
exit /b 0
