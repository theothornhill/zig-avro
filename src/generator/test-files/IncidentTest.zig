//! This is a generated file - DO NOT EDIT!

const std = @import("std");
const avro = @import("zig-avro");

/// Specific information about a Chess incident
pub const ChessSpecifics = struct {
    type: union(enum) { null, Move: Move, Clock: Clock, Evaluation: Evaluation, } = .null,

    const Self = @This();

    pub const ReadError = error{};
    pub const Reader = std.io.Reader(*Self, ReadError, read);

    pub fn reader(self: *Self) Reader {
        return .{ .context = self };
    }

    pub fn read(self: *Self, buf: []u8) ReadError!usize {
        return @errorCast(avro.Reader.read(Self, self, buf));
    }
};

pub const Probabilities = struct {
    white: union(enum) { float: f32, int: i32, },
    draw: union(enum) { float: f32, int: i32, },
    black: union(enum) { float: f32, int: i32, },

    const Self = @This();

    pub const ReadError = error{};
    pub const Reader = std.io.Reader(*Self, ReadError, read);

    pub fn reader(self: *Self) Reader {
        return .{ .context = self };
    }

    pub fn read(self: *Self, buf: []u8) ReadError!usize {
        return @errorCast(avro.Reader.read(Self, self, buf));
    }
};

pub const Goal = struct {
    typeName: []const u8 = .Goal,
    subType: GoalType = .UNKNOWN,

    const Self = @This();

    pub const ReadError = error{};
    pub const Reader = std.io.Reader(*Self, ReadError, read);

    pub fn reader(self: *Self) Reader {
        return .{ .context = self };
    }

    pub fn read(self: *Self, buf: []u8) ReadError!usize {
        return @errorCast(avro.Reader.read(Self, self, buf));
    }
};

pub const SetPlay = struct {
    typeName: []const u8 = .SetPlay,
    subType: SetPlayType = .UNKNOWN,

    const Self = @This();

    pub const ReadError = error{};
    pub const Reader = std.io.Reader(*Self, ReadError, read);

    pub fn reader(self: *Self) Reader {
        return .{ .context = self };
    }

    pub fn read(self: *Self, buf: []u8) ReadError!usize {
        return @errorCast(avro.Reader.read(Self, self, buf));
    }
};

pub const Chance = struct {
    typeName: []const u8 = .Chance,
    subType: ChanceType = .UNKNOWN,

    const Self = @This();

    pub const ReadError = error{};
    pub const Reader = std.io.Reader(*Self, ReadError, read);

    pub fn reader(self: *Self) Reader {
        return .{ .context = self };
    }

    pub fn read(self: *Self, buf: []u8) ReadError!usize {
        return @errorCast(avro.Reader.read(Self, self, buf));
    }
};

/// @deprecated
pub const StockfishEvaluation = struct {
    pawnAdvantage: f32,
    move: []const u8,

    const Self = @This();

    pub const ReadError = error{};
    pub const Reader = std.io.Reader(*Self, ReadError, read);

    pub fn reader(self: *Self) Reader {
        return .{ .context = self };
    }

    pub fn read(self: *Self, buf: []u8) ReadError!usize {
        return @errorCast(avro.Reader.read(Self, self, buf));
    }
};

pub const SetPlayType = enum {
    FREEKICK,
    UNKNOWN,
};

pub const Var = struct {
    typeName: []const u8 = .Var,
    subType: VarType = .UNKNOWN,

    const Self = @This();

    pub const ReadError = error{};
    pub const Reader = std.io.Reader(*Self, ReadError, read);

    pub fn reader(self: *Self) Reader {
        return .{ .context = self };
    }

    pub fn read(self: *Self, buf: []u8) ReadError!usize {
        return @errorCast(avro.Reader.read(Self, self, buf));
    }
};

pub const PenaltyShotType = enum {
    UNKNOWN,
};

/// Specific information about a Football incident
pub const FootballSpecifics = struct {
    type: union(enum) { null, Assist: Assist, Booking: Booking, Chance: Chance, DefensiveAct: DefensiveAct, Foul: Foul, Goal: Goal, Offside: Offside, PenaltyAwarded: PenaltyAwarded, PenaltyShootout: PenaltyShootout, PenaltyShot: PenaltyShot, Save: Save, SetPlay: SetPlay, Skill: Skill, Var: Var, } = .null,

    const Self = @This();

    pub const ReadError = error{};
    pub const Reader = std.io.Reader(*Self, ReadError, read);

    pub fn reader(self: *Self) Reader {
        return .{ .context = self };
    }

    pub fn read(self: *Self, buf: []u8) ReadError!usize {
        return @errorCast(avro.Reader.read(Self, self, buf));
    }
};

pub const PenaltyShootoutType = enum {
    UNKNOWN,
};

pub const AssistType = enum {
    UNKNOWN,
};

pub const BookingType = enum {
    YELLOW_CARD,
    SECOND_YELLOW_CARD,
    RED_CARD,
    UNKNOWN,
};

pub const SaveType = enum {
    UNKNOWN,
};

pub const Clock = struct {
    typeName: []const u8 = .Clock,
    halfMove: i32,
    clock: []const u8,

    const Self = @This();

    pub const ReadError = error{};
    pub const Reader = std.io.Reader(*Self, ReadError, read);

    pub fn reader(self: *Self) Reader {
        return .{ .context = self };
    }

    pub fn read(self: *Self, buf: []u8) ReadError!usize {
        return @errorCast(avro.Reader.read(Self, self, buf));
    }
};

pub const MoveScore = struct {
    LAN: []const u8,
    SAN: []const u8,
    score: i32,
    type: MoveScoreType,
    text: []const u8,
    probabilities: Probabilities,

    const Self = @This();

    pub const ReadError = error{};
    pub const Reader = std.io.Reader(*Self, ReadError, read);

    pub fn reader(self: *Self) Reader {
        return .{ .context = self };
    }

    pub fn read(self: *Self, buf: []u8) ReadError!usize {
        return @errorCast(avro.Reader.read(Self, self, buf));
    }
};

pub const SportType = enum {
    FOOTBALL,
    HANDBALL,
    ICE_HOCKEY,
    CYCLING,
    CHESS,
    VOLLEYBALL,
    BASKETBALL,
    FLOORBALL,
    ALPINE,
    NORDIC_COMBINED,
    CROSS_COUNTRY,
    SKI_JUMPING,
    BIATHLON,
    SHORT_TRACK_SPEED_SKATING,
    SKELETON,
    FREESTYLE_SKIING,
    SNOWBOARDING,
    BOBSLEIGH,
    FIGURE_SKATING,
    CURLING,
    CROSS_COUNTRY_SKIING,
    SPEED_SKATING,
    HARNESS_RACING,
    TENNIS,
    BADMINTON,
    ATHLETICS,
    FUNCTIONAL_FITNESS_AND_CROSSFIT,
    GYMNASTICS,
    MARTIAL_ARTS_BOXING,
    MARTIAL_ARTS_KARATE,
    MARTIAL_ARTS_MMA,
    MOTORSPORT,
    MOTORSPORT_BILCROSS,
    MOTORSPORT_CROSSCART,
    MOTORSPORT_DRAGRACE,
    MOTORSPORT_MOTOSPORT,
    MOTORSPORT_QUADCROSS,
    MOTORSPORT_RADIO,
    MOTORSPORT_RALLYCROSS,
    MOTORSPORT_ROADRACING,
    MOTORSPORT_SNOWSCOOTER,
    MOTORSPORT_TRIAL,
    PADEL,
    SWIMMING,
    OTHER,
    UNKNOWN,
};

pub const Booking = struct {
    typeName: []const u8 = .Booking,
    subType: BookingType = .UNKNOWN,

    const Self = @This();

    pub const ReadError = error{};
    pub const Reader = std.io.Reader(*Self, ReadError, read);

    pub fn reader(self: *Self) Reader {
        return .{ .context = self };
    }

    pub fn read(self: *Self, buf: []u8) ReadError!usize {
        return @errorCast(avro.Reader.read(Self, self, buf));
    }
};

pub const Save = struct {
    typeName: []const u8 = .Save,
    subType: SaveType = .UNKNOWN,

    const Self = @This();

    pub const ReadError = error{};
    pub const Reader = std.io.Reader(*Self, ReadError, read);

    pub fn reader(self: *Self) Reader {
        return .{ .context = self };
    }

    pub fn read(self: *Self, buf: []u8) ReadError!usize {
        return @errorCast(avro.Reader.read(Self, self, buf));
    }
};

pub const SkillType = enum {
    DRIBBLE,
    UNKNOWN,
};

pub const Move = struct {
    typeName: []const u8 = .Move,
    halfMove: i32,
    LAN: []const u8,
    SAN: []const u8,
    FEN: []const u8,

    const Self = @This();

    pub const ReadError = error{};
    pub const Reader = std.io.Reader(*Self, ReadError, read);

    pub fn reader(self: *Self) Reader {
        return .{ .context = self };
    }

    pub fn read(self: *Self, buf: []u8) ReadError!usize {
        return @errorCast(avro.Reader.read(Self, self, buf));
    }
};

pub const FoulType = enum {
    DANGEROUS_PLAY,
    UNKNOWN,
};

pub const Assist = struct {
    typeName: []const u8 = .Assist,
    subType: AssistType = .UNKNOWN,

    const Self = @This();

    pub const ReadError = error{};
    pub const Reader = std.io.Reader(*Self, ReadError, read);

    pub fn reader(self: *Self) Reader {
        return .{ .context = self };
    }

    pub fn read(self: *Self, buf: []u8) ReadError!usize {
        return @errorCast(avro.Reader.read(Self, self, buf));
    }
};

pub const IncidentType = enum {
    START_FIRST_PERIOD,
    END_FIRST_PERIOD,
    START_SECOND_PERIOD,
    END_SECOND_PERIOD,
    START_THIRD_PERIOD,
    END_THIRD_PERIOD,
    END_FIRST_EXTRA_TIME_PERIOD,
    END_SECOND_EXTRA_TIME_PERIOD,
    END_THIRD_EXTRA_TIME_PERIOD,
    END_FOURTH_EXTRA_TIME_PERIOD,
    END_FIFTH_EXTRA_TIME_PERIOD,
    END_SIXTH_EXTRA_TIME_PERIOD,
    END_SEVENTH_EXTRA_TIME_PERIOD,
    START_FIRST_EXTRA_TIME_PERIOD,
    START_SECOND_EXTRA_TIME_PERIOD,
    START_THIRD_EXTRA_TIME_PERIOD,
    START_FOURTH_EXTRA_TIME_PERIOD,
    START_FIFTH_EXTRA_TIME_PERIOD,
    START_SIXTH_EXTRA_TIME_PERIOD,
    START_SEVENTH_EXTRA_TIME_PERIOD,
    START_EIGHTH_EXTRA_TIME_PERIOD,
    EXPERT_COMMENT,
    COMMENT,
    LINEUP_READY,
    CORNER,
    SHOT,
    FIRST_HALF,
    HALF_TIME,
    SECOND_HALF,
    FULL_TIME,
    FIRST_HALF_EXTRA_TIME,
    SECOND_HALF_EXTRA_TIME,
    THIRD_HALF_EXTRA_TIME,
    FOURTH_HALF_EXTRA_TIME,
    PENALTIES_SHOOTOUT,
    FIRST_PERIOD,
    SECOND_PERIOD,
    THIRD_PERIOD,
    FOURTH_PERIOD,
    EXTRA_TIME,
    BREAK,
    FACE_OFF,
    TIMEOUT,
    TEN_MIN_SUSPENSION,
    TWO_MIN_BENCH_SUSPENSION,
    TWO_MIN_SUSPENSION,
    TWENTY_MIN_SUSPENSION,
    TWENTY_FIVE_MIN_SUSPENSION,
    FIVE_MIN_SUSPENSION,
    CANCELLED_CARD,
    DISQUALIFICATION,
    EXCLUSION,
    GAME_MISCONDUCT,
    MATCH_PENALTY,
    COINCIDENTAL_PENALTY,
    RED_CARD,
    YELLOW_CARD,
    BLUE_CARD,
    SECOND_YELLOW_CARD,
    DEFENSIVE_FOUL,
    OFFENSIVE_FOUL,
    UNSPORTMANLIKE_FOUL,
    TWO_POINT_CONVERSION,
    CANCELLED_GOAL,
    CANCELLED_MISSED_PENALTY,
    CANCELLED_PENALTY,
    CONVERSION,
    DEFENSIVE_TWO_POINT_CONVERSION,
    DROPKICK,
    EXTRA_POINT,
    EXTRA_TIME_CONVERSION,
    EXTRA_TIME_DROPKICK,
    EXTRA_TIME_PENALTY,
    EXTRA_TIME_PENALTY_TRY,
    EXTRA_TIME_TRY,
    EXTRA_TIME_GOAL,
    EXTRA_TIME_MISSED_PENALTY,
    EXTRA_TIME_OWN_GOAL,
    EXTRA_TIME_PENALTY_SCORED,
    FIELD_GOAL,
    GOLDEN_POINT_DROPKICK,
    GOLDEN_POINT_PENALTY,
    GOLDEN_POINT_TRY,
    MISSED_PENALTY,
    OFFSIDE,
    OWN_GOAL,
    PENALTY,
    PENALTY_TRY,
    PENALTY_TRY_CONVERSION,
    PENALTY_SHOOTOUT_MISSED,
    PENALTY_SHOOTOUT_SCORED,
    POWER_PLAY_GOAL,
    REGULAR_GOAL,
    SAFETY,
    SCORING_STATISTICS,
    SHORT_HANDED_GOAL,
    SINGLE_POINT,
    TOUCHDOWN,
    TRY,
    ASSIST,
    SECOND_ASSIST,
    ONE_POINT_GOAL,
    TWO_POINT_GOAL,
    THREE_POINT_GOAL,
    ONE_POINT_MISS,
    TWO_POINT_MISS,
    THREE_POINT_MISS,
    BLOCK,
    SUBSTITUTION_OUT,
    SUBSTITUTION_IN,
    SUBSTITUTION_GOALKEEPER_OUT,
    SUBSTITUTION_GOALKEEPER_IN,
    CLOCK_START,
    CLOCK_STOP,
    CLOCK_UPDATE,
    EVENT_START,
    EVENT_END,
    PERIOD_START,
    PERIOD_END,
    PRELIM_PERIOD_END,
    PRELIM_EVENT_END,
    VAR,
    FREE_KICK,
    INJURY,
    SUMMARY,
    TECHNICAL_FAULT,
    PENALTY_AWARDED,
    MISSED_SHOT,
    CHESS_MOVE,
    CHESS_CLOCK,
    CHESS_EVALUATION,
    UNKNOWN,
};

pub const PenaltyShootout = struct {
    typeName: []const u8 = .PenaltyShootout,
    subType: PenaltyShootoutType = .UNKNOWN,

    const Self = @This();

    pub const ReadError = error{};
    pub const Reader = std.io.Reader(*Self, ReadError, read);

    pub fn reader(self: *Self) Reader {
        return .{ .context = self };
    }

    pub fn read(self: *Self, buf: []u8) ReadError!usize {
        return @errorCast(avro.Reader.read(Self, self, buf));
    }
};

pub const GoalType = enum {
    REGULAR_GOAL,
    UNKNOWN,
};

pub const PenaltyAwarded = struct {
    typeName: []const u8 = .PenaltyAwarded,
    subType: PenaltyAwardedType = .UNKNOWN,

    const Self = @This();

    pub const ReadError = error{};
    pub const Reader = std.io.Reader(*Self, ReadError, read);

    pub fn reader(self: *Self) Reader {
        return .{ .context = self };
    }

    pub fn read(self: *Self, buf: []u8) ReadError!usize {
        return @errorCast(avro.Reader.read(Self, self, buf));
    }
};

pub const Evaluation = struct {
    typeName: []const u8 = .Evaluation,
    halfMove: i32,
    FEN: []const u8,
    probabilities: ?Probabilities = null,
    bestMoves: ?avro.Array(StockfishEvaluation) = null,
    moves: avro.Array(MoveScore),
    ponderTimeMs: i32,

    const Self = @This();

    pub const ReadError = error{};
    pub const Reader = std.io.Reader(*Self, ReadError, read);

    pub fn reader(self: *Self) Reader {
        return .{ .context = self };
    }

    pub fn read(self: *Self, buf: []u8) ReadError!usize {
        return @errorCast(avro.Reader.read(Self, self, buf));
    }
};

pub const DefensiveActType = enum {
    UNKNOWN,
};

pub const Incident = struct {
    id: []const u8,
    masterId: ?[]const u8 = null,
    eventId: []const u8,
    participantId: ?[]const u8 = null,
    referencedParticipantId: ?[]const u8 = null,
    sportType: SportType = .UNKNOWN,
    sportSpecifics: union(enum) { null, FootballSpecifics: FootballSpecifics, ChessSpecifics: ChessSpecifics, } = .null,
    incidentType: IncidentType = .UNKNOWN,
    elapsedTime: ?i32 = null,
    sortOrder: ?i32 = null,
    deleted: bool,
    tsConnectorIn: ?i64 = null,
    tsConnectorOut: ?i64 = null,
    connectorId: ?[]const u8 = null,
    tsAdminIn: ?i64 = null,
    tsAdminOut: ?i64 = null,
    properties: avro.Map([]const u8),

    const Self = @This();

    pub const ReadError = error{};
    pub const Reader = std.io.Reader(*Self, ReadError, read);

    pub fn reader(self: *Self) Reader {
        return .{ .context = self };
    }

    pub fn read(self: *Self, buf: []u8) ReadError!usize {
        return @errorCast(avro.Reader.read(Self, self, buf));
    }
};

pub const PenaltyAwardedType = enum {
    UNKNOWN,
};

pub const OffsideType = enum {
    UNKNOWN,
};

pub const Skill = struct {
    typeName: []const u8 = .Skill,
    subType: SkillType = .UNKNOWN,

    const Self = @This();

    pub const ReadError = error{};
    pub const Reader = std.io.Reader(*Self, ReadError, read);

    pub fn reader(self: *Self) Reader {
        return .{ .context = self };
    }

    pub fn read(self: *Self, buf: []u8) ReadError!usize {
        return @errorCast(avro.Reader.read(Self, self, buf));
    }
};

pub const DefensiveAct = struct {
    typeName: []const u8 = .DefensiveAct,
    subType: DefensiveActType = .UNKNOWN,

    const Self = @This();

    pub const ReadError = error{};
    pub const Reader = std.io.Reader(*Self, ReadError, read);

    pub fn reader(self: *Self) Reader {
        return .{ .context = self };
    }

    pub fn read(self: *Self, buf: []u8) ReadError!usize {
        return @errorCast(avro.Reader.read(Self, self, buf));
    }
};

pub const ChanceType = enum {
    MISS,
    UNKNOWN,
};

pub const Foul = struct {
    typeName: []const u8 = .Foul,
    subType: FoulType = .UNKNOWN,

    const Self = @This();

    pub const ReadError = error{};
    pub const Reader = std.io.Reader(*Self, ReadError, read);

    pub fn reader(self: *Self) Reader {
        return .{ .context = self };
    }

    pub fn read(self: *Self, buf: []u8) ReadError!usize {
        return @errorCast(avro.Reader.read(Self, self, buf));
    }
};

pub const Offside = struct {
    typeName: []const u8 = .Offside,
    subType: OffsideType = .UNKNOWN,

    const Self = @This();

    pub const ReadError = error{};
    pub const Reader = std.io.Reader(*Self, ReadError, read);

    pub fn reader(self: *Self) Reader {
        return .{ .context = self };
    }

    pub fn read(self: *Self, buf: []u8) ReadError!usize {
        return @errorCast(avro.Reader.read(Self, self, buf));
    }
};

pub const MoveScoreType = enum {
    CENTIPAWN,
    MATE,
    UNDEFINED,
};

pub const PenaltyShot = struct {
    typeName: []const u8 = .PenaltyShot,
    subType: PenaltyShotType = .UNKNOWN,

    const Self = @This();

    pub const ReadError = error{};
    pub const Reader = std.io.Reader(*Self, ReadError, read);

    pub fn reader(self: *Self) Reader {
        return .{ .context = self };
    }

    pub fn read(self: *Self, buf: []u8) ReadError!usize {
        return @errorCast(avro.Reader.read(Self, self, buf));
    }
};

pub const VarType = enum {
    INITIATED,
    CONCLUDED,
    VAR_INCIDENT_GOAL_POSSIBLE_BALL_NOT_ACROSS_LINE,
    VAR_RESULT_GOAL_POSSIBLE_BALL_NOT_ACROSS_LINE_GOAL_CONFIRMED,
    VAR_RESULT_GOAL_POSSIBLE_BALL_NOT_ACROSS_LINE_GOAL_OVERRULED,
    VAR_INCIDENT_GOAL_POSSIBLE_BALL_OUT_OF_PLAY,
    VAR_RESULT_GOAL_POSSIBLE_BALL_OUT_OF_PLAY_GOAL_CONFIRMED,
    VAR_RESULT_GOAL_POSSIBLE_BALL_OUT_OF_PLAY_GOAL_OVERRULED,
    VAR_INCIDENT_GOAL_POSSIBLE_FAULT_ATTACK,
    VAR_RESULT_GOAL_POSSIBLE_FAULT_ATTACK_GOAL_CONFIRMED,
    VAR_RESULT_GOAL_POSSIBLE_FAULT_ATTACK_GOAL_OVERRULED,
    VAR_INCIDENT_GOAL_POSSIBLE_OFFSIDE,
    VAR_RESULT_GOAL_POSSIBLE_OFFSIDE_GOAL_CONFIRMED,
    VAR_RESULT_GOAL_POSSIBLE_OFFSIDE_GOAL_OVERRULED,
    VAR_INCIDENT_IDENTITY,
    VAR_RESULT_CORRECT_IDENTITY,
    VAR_RESULT_WRONG_IDENTITY_RED_CARD,
    VAR_RESULT_WRONG_IDENTITY_YELLOW_CARD,
    VAR_INCIDENT_PENALTY_EXECUTION,
    VAR_RESULT_PENALTY_EXECUTION_GOAL_CONFIRMED,
    VAR_RESULT_PENALTY_EXECUTION_GOAL_OVERRULED,
    VAR_RESULT_PENALTY_EXECUTION_GOAL,
    VAR_RESULT_PENALTY_EXECUTION_NOT_GOAL,
    VAR_RESULT_PENALTY_EXECUTION_NEW_PENALTY,
    VAR_INCIDENT_PENALTY_POSSIBLE_BALL_OUT_OF_PLAY,
    VAR_RESULT_PENALTY_POSSIBLE_BALL_OUT_OF_PLAY_PENALTY_CONFIRMED,
    VAR_RESULT_PENALTY_POSSIBLE_BALL_OUT_OF_PLAY_PENALTY_OVERRULED,
    VAR_INCIDENT_PENALTY_POSSIBLE_FAULT_ATTACK,
    VAR_RESULT_PENALTY_POSSIBLE_FAULT_ATTACK_PENALTY_CONFIRMED,
    VAR_RESULT_PENALTY_POSSIBLE_FAULT_ATTACK_PENALTY_OVERRULED,
    VAR_INCIDENT_PENALTY_POSSIBLE_FAULT_OUTSIDE_PENALTY_BOX,
    VAR_RESULT_PENALTY_POSSIBLE_FAULT_OUTSIDE_PENALTY_BOX_PENALTY_CONFIRMED,
    VAR_RESULT_PENALTY_POSSIBLE_FAULT_OUTSIDE_PENALTY_BOX_PENALTY_OVERRULED,
    VAR_INCIDENT_PENALTY_POSSIBLE_NO_FAULT,
    VAR_RESULT_PENALTY_POSSIBLE_NO_FAULT_PENALTY_CONFIRMED,
    VAR_RESULT_PENALTY_POSSIBLE_NO_FAULT_PENALTY_OVERRULED,
    VAR_INCIDENT_PENALTY_POSSIBLE_OFFSIDE,
    VAR_RESULT_PENALTY_POSSIBLE_OFFSIDE_PENALTY_CONFIRMED,
    VAR_RESULT_PENALTY_POSSIBLE_OFFSIDE_PENALTY_OVERRULED,
    VAR_INCIDENT_POSSIBLE_PENALTY_POSSIBLE_BALL_OUT_OF_PLAY,
    VAR_RESULT_POSSIBLE_PENALTY_POSSIBLE_BALL_OUT_OF_PLAY_PENALTY_CONFIRMED,
    VAR_RESULT_POSSIBLE_PENALTY_POSSIBLE_BALL_OUT_OF_PLAY_PENALTY_OVERRULED,
    VAR_INCIDENT_POSSIBLE_PENALTY_POSSIBLE_FAULT_ATTACK,
    VAR_RESULT_POSSIBLE_PENALTY_POSSIBLE_FAULT_ATTACK_PENALTY_CONFIRMED,
    VAR_RESULT_POSSIBLE_PENALTY_POSSIBLE_FAULT_ATTACK_PENALTY_OVERRULED,
    VAR_INCIDENT_POSSIBLE_PENALTY_POSSIBLE_FAULT_OUTSIDE_PENALTY_BOX,
    VAR_RESULT_POSSIBLE_PENALTY_POSSIBLE_FAULT_OUTSIDE_PENALTY_BOX_PENALTY_CONFIRMED,
    VAR_RESULT_POSSIBLE_PENALTY_POSSIBLE_FAULT_OUTSIDE_PENALTY_BOX_PENALTY_OVERRULED,
    VAR_INCIDENT_POSSIBLE_PENALTY_POSSIBLE_NO_FAULT,
    VAR_RESULT_POSSIBLE_PENALTY_POSSIBLE_NO_FAULT_PENALTY_CONFIRMED,
    VAR_RESULT_POSSIBLE_PENALTY_POSSIBLE_NO_FAULT_PENALTY_OVERRULED,
    VAR_INCIDENT_POSSIBLE_PENALTY_POSSIBLE_OFFSIDE,
    VAR_RESULT_POSSIBLE_PENALTY_POSSIBLE_OFFSIDE_PENALTY_CONFIRMED,
    VAR_RESULT_POSSIBLE_PENALTY_POSSIBLE_OFFSIDE_PENALTY_OVERRULED,
    VAR_INCIDENT_POSSIBLE_RED_CARD,
    VAR_RESULT_POSSIBLE_RED_CARD_CONFIRMED,
    VAR_RESULT_POSSIBLE_RED_CARD_OVERRULED,
    VAR_INCIDENT_RED_CARD,
    VAR_RESULT_RED_CARD_CONFIRMED,
    VAR_RESULT_RED_CARD_OVERRULED,
    VAR_CAN,
    CELLED,
    VAR_RESULT_CANCELLED,
    VAR_NO_CHECK_GOAL,
    VAR_NO_CHECK_GOAL_CONFIRMED,
    UNKNOWN,
};

