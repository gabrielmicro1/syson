package Behavior {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    doc /* Behavior constructs used by task reference models. */
    item def Notice { attribute soc : Real; }
    item def Command { attribute code : Integer; }
    port def NoticePort { out item notice : Notice; }
    port def CommandPort { out item command : Command; }
    action def SwitchOff;
    calc def Share {
        in a : Real;
        in b : Real;
        return : Real = (if a >= b ? a else b) / (a + b);
    }
    part def Precedence {
        attribute a : Real;
        attribute b : Real;
        attribute c : Real;
        attribute sumOverC : Real = (a + b) / c;
        attribute diffOfDiff : Real = a - (b - c);
        attribute negSum : Real = -(a + b);
        attribute powOfPow : Real = (a ** b) ** c;
        attribute mixed : Real = a * b + c;
        attribute chained : Real = a + b + c;
        attribute guarded : Boolean = (a > b) and (b > c or c > a);
        attribute flags : Boolean[3];
        attribute second : Boolean = flags#(2) and not flags#(3);
    }
    part def Controller {
        port obcLink : NoticePort;
        port noticeIn : ~NoticePort;
        port cmdIn : ~CommandPort;
        attribute stateOfCharge : Real;
        attribute temperature : ThermodynamicTemperatureValue;
        attribute onBelow : ThermodynamicTemperatureValue;
        attribute enabled : Boolean;
        attribute share : Real = if stateOfCharge > 0.5 ? 1.0 else 0.0;
        action notifyByItem {
            item notice : Notice { attribute :>> soc = stateOfCharge; }
            first start;
            then action send1 send notice via obcLink;
            then done;
        }
        action heaterCycleOwner {
            loop action heaterCycle {
                action waitCold accept when temperature < onBelow;
                then action off : SwitchOff;
            }
        }
        action notifySelf {
            first start;
            then action sendSelf send notice3 to this;
            then done;
            item notice3 : Notice;
        }
        action routeCommand {
            action receive accept cmd : Command via cmdIn;
            then decide;
                if receive.cmd.code == 1 then off1;
                if receive.cmd.code != 1 then off2;
            action off1 : SwitchOff;
            action off2 : SwitchOff;
        }
        action enable {
            first start;
            then action enableIt assign enabled := true;
            then done;
        }
        exhibit state modes {
            entry; then normal;
            state normal;
            state shed {
                entry action shedPayload {
                    action payloadOff : SwitchOff;
                    then action notifyObc send notice2 via obcLink;
                    item notice2 : Notice { attribute :>> soc = stateOfCharge; }
                }
            }
            transition first normal accept when stateOfCharge < 0.3 then shed;
            transition recover first shed accept msg : Notice via noticeIn if msg.soc > 0.5 then normal;
        }
    }
}
