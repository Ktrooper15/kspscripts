// Pre Launch Checks
SAS on.
Lock Throttle to 0.
RCS off.

clearscreen.
PRINT "Counting down:".
FROM {local countdown is 10.} UNTIL countdown = 0 STEP {SET countdown to countdown - 1.} DO {
    PRINT "..." + countdown.
    WAIT 1. 

Function main {
  doLaunch().
  doAscent().
  until apoapsis > 100000 {
    doAutoStage().
  }
  doShutdown().
  doCircularization().
  print "It ran!".
  unlock steering.
  wait until false.
}

Function doCircularization {
  local circ is list(time:seconds + 30, 0, 0, 0).
  until false {
    local oldScore is score(circ).
    set circ to improve(circ).
    if oldScore <= score(circ) {
      break.
    }
  }
  executeManeuver(circ).
}

Function score {
    parameter data.
    local mnv is node(data[0], data[1], data[2], data[3]).
    addManeuverToFlightPlan(mnv).
    local result is mnv:score:orbit:eccentricity. 
    removeManeuverFromFlightPlan(mnv).
    return result.
}

Function improve {
    parameter data.
    local scoreToBeat is score(data).
    local bestCandidate is data.
    local candidates is list(
        list(data[0] + 1, data[1], data[2], data[3]),
        list(data[0] - 1, data[1], data[2], data[3]),
        list(data[0], data[1] + 1, data[2], data[3]),
        list(data[0], data[1] - 1, data[2], data[3]),
        list(data[0], data[1], data[2] + 1, data[3]),
        list(data[0], data[1], data[2] - 1, data[3]),
        list(data[0], data[1], data[2], data[3] +1),
        list(data[0], data[1], data[2], data[3]-1)
    ).
    for candidate in candidate {
        local candidateScore is score(candidate).
        if candidateScore < scoreToBeat {
            set scoreToBeat to candidateScore.
            set bestCandidate to candidate.
        }
    }
    return bestCandidate.
}

Function executeManeuver {
    parameter mList.
    local mnv is node(mList[0], mList[1], mList[2], mList[3]).
    addManeuverToFlightPlan(mnv).
    local startTime is calculateStartTime(mnv).
    wait Until time:seconds > startTime -10.
    lockSteeringAtManeuverTartget(mnv).
    wait until time:seconds > startTime.
    Lock throttle to 1.
    wait until isManeuverComplete(mnv).
    lock throttle to 0. 
    removeManeuverFromFlightPlan(mnv).
}

Function addManeuverToFlightPlan {
    parameter mnv.
    add mnv.
}

function calulateStartTime {
    parameter mnv.
    return time:seconds + mnv:eta - maneuverBurnTime(mnv) / 2.
}

function maneuverBurnTime {
    parameter mnv.
    local dv is mnv:deltaV:mag.
    local g0 is 9.80665.
    local isp is 0.

    list engines in myEngines. 
    for en in myEngines {
        if en:ignition and not en:flameout {
            set is to isp + (en:isp * (en:maxThrust / ship:maxThrust)).
        }
    }

    local mf is ship:mass / constant():e^(dv / (isp * g0)).
    Local FuelFlow is ship:maxThrust / (isp * g0).
    local t is (ship:mass - mf) / fuelFlow.

    return t.
}

Function lockSteeringAtManeuverTartget {
    parameter mnv.
    lock steering to mnv:burnvector.
    
}

Function isManeuverComplete {
  parameter mnv.
  if not(defined originalVector) or originalVector = -1 {
    declare global originalVector to mnv:burnvector.
  }
  if vang(originalVector, mnv:burnvector) > 90 {
    declare global originalVector to -1.
    return true.
  }
  return false.
}

Function removeManeuverFromFlightPlan {
    parameter mnv.
    remove mnv.
}

Function doLaunch{
    LOCK throttle to 1.
    doSafeStage().
    doSafeStage(). 
}

Function doAscent {
    lock targetPitch to 88.963 - 1.03287 * alt:radar^0.409511.
    set targetDirection to 90.
    lock steering to heading(targetDirection, targetPitch).
}

Function doAutoStage {
  if not(defined oldThrust) {
    global oldThrust is ship:availablethrust.
  }
  if ship:availablethrust < (oldThrust - 10) {
    doSafeStage(). wait 1.
    global oldThrust is ship:availablethrust.
  }
}

Function doShutdown {
    lock throttle to 0.
    lock steering to prograde.
}

Function doSafeStage {
  wait until stage:ready.
  stage.
}

main().