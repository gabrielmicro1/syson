package RemoteMonitoringStation {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;

    doc /* Worked example for the SysML v2 style guide: a solar-powered remote temperature
         * monitoring station. Every rule in the guide is applied at least once. */

    package Definitions {
        doc /* Reusable definitions. Nothing here refers to anything outside Definitions. */

        package AttributeDefinitions {
            enum def StationMode {
                doc /* Operating modes of the station. */
                enum normal;
                enum lowPower;
            }
        }

        package ItemDefinitions {
            item def <'D-1'> DCPower {
                doc /* Unregulated DC electrical power. */
                attribute voltage : ElectricPotentialValue;
                attribute current : ElectricCurrentValue;
            }
            item def <'D-2'> SensorReading {
                doc /* One temperature measurement. */
                attribute temperature : ThermodynamicTemperatureValue;
            }
            item def <'D-3'> Telemetry {
                doc /* Telemetry frame sent by the station. */
                attribute stateOfCharge : Real {
                    doc /* Battery state of charge as a fraction (0.40 = 40 %). */
                }
            }
        }

        package PortDefinitions {
            private import ItemDefinitions::*;
            port def DCPowerPort {
                doc /* Supplies DC power. Conjugate (~) to receive it. */
                out item power : DCPower;
            }
            port def SensorDataPort {
                doc /* Supplies sensor readings. Conjugate (~) to receive them. */
                out item reading : SensorReading;
            }
            port def TelemetryPort {
                doc /* Supplies telemetry. */
                out item telemetry : Telemetry;
            }
        }

        package InterfaceDefinitions {
            private import PortDefinitions::*;
            interface def DCPowerInterface {
                doc /* Connects a DC power source to a DC power sink. */
                end source : DCPowerPort;
                end sink : ~DCPowerPort;
            }
            interface def SensorDataInterface {
                doc /* Connects a sensor data source to its consumer. */
                end source : SensorDataPort;
                end sink : ~SensorDataPort;
            }
        }

        package PartDefinitions {
            doc /* Black boxes: ports and attributes only. Decomposition lives in PartsTree. */
            private import AttributeDefinitions::*;
            private import PortDefinitions::*;
            part def Station {
                doc /* The monitoring station as a whole. */
                port telemetryOut : TelemetryPort;
                attribute mass : MassValue;
            }
            part def SolarPanel {
                doc /* Photovoltaic panel. */
                port powerOut : DCPowerPort;
                attribute mass : MassValue;
                attribute ratedPower : PowerValue;
            }
            part def BatteryPack {
                doc /* Rechargeable battery pack. */
                port powerIn : ~DCPowerPort;
                port powerOut : DCPowerPort;
                attribute mass : MassValue;
            }
            part def Cell {
                doc /* One battery cell. */
                attribute mass : MassValue;
            }
            part def Controller {
                doc /* Station controller: distributes power, collects readings, sends telemetry. */
                port powerIn : ~DCPowerPort;
                port sensorPowerOut : DCPowerPort;
                port sensorIn : ~SensorDataPort;
                port telemetryOut : TelemetryPort;
                attribute mass : MassValue;
                attribute powerDraw : PowerValue;
                attribute mode : StationMode;
                attribute stateOfCharge : Real {
                    doc /* Battery state of charge as a fraction (0.40 = 40 %). */
                }
            }
            part def TemperatureSensor {
                doc /* Air temperature sensor. */
                port powerIn : ~DCPowerPort;
                port dataOut : SensorDataPort;
                attribute mass : MassValue;
                attribute powerDraw : PowerValue;
            }
        }

        package ActionDefinitions {
            private import ItemDefinitions::*;
            action def GeneratePower {
                doc /* Convert sunlight into DC power. */
                out power : DCPower;
            }
            action def StoreEnergy {
                doc /* Store DC power and release it on demand. */
                in power : DCPower;
            }
            action def MeasureTemperature {
                doc /* Measure air temperature. */
                out reading : SensorReading;
            }
            action def ReportTelemetry {
                doc /* Package readings into telemetry and send it. */
                in reading : SensorReading;
                out telemetry : Telemetry;
            }
        }

        package CalculationDefinitions {
            calc def PowerMargin {
                doc /* Power left over after the loads are supplied. */
                in generated : PowerValue;
                in consumed : PowerValue;
                return margin : PowerValue = generated - consumed;
            }
        }

        package RequirementDefinitions {
            requirement def MaximumMass {
                doc /* Shared pattern: the subject's mass shall not exceed a limit. */
                attribute massActual : MassValue;
                attribute massLimit : MassValue;
                require constraint { massActual <= massLimit }
            }
        }
    }

    package ActionTree {
        private import Definitions::ActionDefinitions::*;
        action stationFunctions {
            doc /* Functional breakdown of the station. */
            first start;
            then action generatePower : GeneratePower;
            then action storeEnergy : StoreEnergy;
            then action measureTemperature : MeasureTemperature;
            then action reportTelemetry : ReportTelemetry;
            then done;
            flow generatePower.power to storeEnergy.power;
            flow measureTemperature.reading to reportTelemetry.reading;
        }
    }

    package PartsTree {
        private import Definitions::PartDefinitions::*;
        private import Definitions::InterfaceDefinitions::*;
        part station : Station {
            doc /* The single system usage tree. */
            attribute :>> mass = solarPanel.mass + batteryPackA.mass + batteryPackB.mass
                + controller.mass + sensor.mass;

            part <'1.1'> solarPanel : SolarPanel {
                attribute :>> mass = 1.5 [kg];
                attribute :>> ratedPower = 40 [W];
                perform ActionTree::stationFunctions.generatePower;
            }
            part <'1.2'> batteryPackA : BatteryPack {
                doc /* Identical to batteryPackB; each pack spells out its own cells. */
                attribute :>> mass = cellA1.mass + cellA2.mass;
                part <'1.2.1'> cellA1 : Cell { attribute :>> mass = 0.05 [kg]; }
                part <'1.2.2'> cellA2 : Cell { attribute :>> mass = 0.05 [kg]; }
                perform ActionTree::stationFunctions.storeEnergy;
            }
            part <'1.3'> batteryPackB : BatteryPack {
                doc /* Identical to batteryPackA; each pack spells out its own cells. */
                attribute :>> mass = cellB1.mass + cellB2.mass;
                part <'1.3.1'> cellB1 : Cell { attribute :>> mass = 0.05 [kg]; }
                part <'1.3.2'> cellB2 : Cell { attribute :>> mass = 0.05 [kg]; }
                perform ActionTree::stationFunctions.storeEnergy;
            }
            part <'1.4'> controller : Controller {
                attribute :>> mass = 0.3 [kg];
                attribute :>> powerDraw = 2 [W];
                attribute lowPowerThreshold : Real = 0.3 {
                    doc /* Enter low power below this state of charge (fraction). */
                }
                attribute recoveryThreshold : Real = 0.5 {
                    doc /* Return to normal above this state of charge (fraction). */
                }
                perform ActionTree::stationFunctions.reportTelemetry;
                exhibit state modes {
                    doc /* Operating modes. */
                    entry; then normal;
                    state normal;
                    state lowPower;
                    transition enterLowPower
                        first normal
                        accept when stateOfCharge < lowPowerThreshold
                        then lowPower;
                    transition recover
                        first lowPower
                        accept when stateOfCharge > recoveryThreshold
                        then normal;
                }
            }
            part <'1.5'> sensor : TemperatureSensor {
                attribute :>> mass = 0.1 [kg];
                attribute :>> powerDraw = 0.5 [W];
                perform ActionTree::stationFunctions.measureTemperature;
            }

            interface <'I-1'> panelToPackA : DCPowerInterface
                connect source ::> solarPanel.powerOut to sink ::> batteryPackA.powerIn;
            interface <'I-2'> panelToPackB : DCPowerInterface
                connect source ::> solarPanel.powerOut to sink ::> batteryPackB.powerIn;
            interface <'I-3'> packAToController : DCPowerInterface
                connect source ::> batteryPackA.powerOut to sink ::> controller.powerIn;
            interface <'I-4'> packBToController : DCPowerInterface
                connect source ::> batteryPackB.powerOut to sink ::> controller.powerIn;
            interface <'I-5'> controllerToSensorPower : DCPowerInterface
                connect source ::> controller.sensorPowerOut to sink ::> sensor.powerIn;
            interface <'I-6'> sensorToController : SensorDataInterface
                connect source ::> sensor.dataOut to sink ::> controller.sensorIn;

            bind telemetryOut = controller.telemetryOut;
        }
    }

    package Requirements {
        private import Definitions::PartDefinitions::*;
        private import Definitions::RequirementDefinitions::*;

        package PhysicalRequirements {
            requirement <'R-PHY-1'> stationMass : MaximumMass {
                doc /* The station shall have a mass of no more than 5 kg. */
                subject station : Station;
                attribute :>> massActual = station.mass;
                attribute :>> massLimit = 5 [kg];
            }
            requirement <'R-PHY-2'> batteryPackMass : MaximumMass {
                doc /* Each battery pack shall have a mass of no more than 0.5 kg. */
                subject pack : BatteryPack;
                attribute :>> massActual = pack.mass;
                attribute :>> massLimit = 0.5 [kg];
            }
        }

        package PerformanceRequirements {
            requirement <'R-PRF-1'> sensorPowerDraw {
                doc /* The temperature sensor shall draw no more than 1 W. */
                subject sensor : TemperatureSensor;
                require constraint { sensor.powerDraw <= 1 [W] }
            }
        }

        package FunctionalRequirements {
            requirement <'R-FUN-1'> telemetryReporting {
                doc /* The station shall report the temperatures it measures in its telemetry. */
                subject station : Station;
            }
        }
    }

    package Analysis {
        private import Definitions::CalculationDefinitions::*;
        doc /* Given parameters and budget evaluations. */

        attribute <'P-1'> panelDerating : Real = 0.8 {
            doc /* Fraction of rated panel power available after ageing and temperature losses. */
        }
        attribute availablePower : PowerValue = PartsTree::station.solarPanel.ratedPower * panelDerating;
        attribute loadPower : PowerValue =
            PartsTree::station.controller.powerDraw + PartsTree::station.sensor.powerDraw;
        attribute powerMargin : PowerValue = PowerMargin(availablePower, loadPower);
    }

    package Traceability {
        satisfy Requirements::PhysicalRequirements::stationMass by PartsTree::station;
        satisfy Requirements::PhysicalRequirements::batteryPackMass by PartsTree::station.batteryPackA;
        satisfy Requirements::PhysicalRequirements::batteryPackMass by PartsTree::station.batteryPackB;
        satisfy Requirements::PerformanceRequirements::sensorPowerDraw by PartsTree::station.sensor;
        satisfy Requirements::FunctionalRequirements::telemetryReporting by PartsTree::station;
    }

    package Views {
        doc /* Diagrams, each created on this package. */
        view partsTreeView : StandardViewDefinitions::GeneralView {
            expose PartsTree::station::**;
        }
    }
}
