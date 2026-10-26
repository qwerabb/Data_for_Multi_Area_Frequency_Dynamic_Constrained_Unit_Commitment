function data = system_data(nt)
% SYSTEM_DATA  Build MAFCUC input data from the full matrix data file.
%
% The complete base matrices stay in data.m. This function only converts
% those matrices into the struct fields required by the MAFCUC model, and
% fills fields that are not present in data.m with the original defaults.
% SYSTEM_DATA() keeps the original one-period debug case. SYSTEM_DATA(24)
% builds the complete daily case without requiring a source-code edit.

if nargin < 1 || isempty(nt)
    nt = 24;
end
validateattributes(nt,{'numeric'},{'scalar','integer','>=',1,'<=',24}, ...
    mfilename,'nt');

%% 1. Load complete source matrices from data.m
% data.m keeps the original full matrices:
%   data_b  bus data
%   data_g  thermal generator data
%   data_l  branch data
%   data_r  renewable plant data
%   data_dc data center data
source_data = str2func('data');
[data_b, data_g, data_l, data_r, data_dc] = source_data();

baseMVA = 100;

data.raw.bus    = data_b;
data.raw.gen    = data_g;
data.raw.branch = data_l;
data.raw.ren    = data_r;
data.raw.dc     = data_dc;

%% 2. Basic system settings
data.baseMVA = baseMVA;
data.f0      = 50;
data.nb      = size(data_b, 1);
data.ng      = size(data_g, 1);
data.na      = 3;
data.nt      = nt;
data.debug_time_index = 1;  % data.nt < 24时，从24小时曲线的该时段开始截取

%% 3. Areas and bus load distribution from data_b
% data_b columns follow MATPOWER style:
% 1 bus_i, 3 Pd, 7 area. data.m already applies its Pd scale.
data.bus_area = zeros(data.nb, 1);
data.bus_area(data_b(:, 1)) = data_b(:, 7);
data.area_buses = cell(1, data.na);
for a = 1:data.na
    data.area_buses{a} = data_b(data_b(:, 7) == a, 1)';
end

area_pd = zeros(1, data.na);
for a = 1:data.na
    area_pd(a) = sum(data_b(data_b(:, 7) == a, 3));
end
data.area_load_ratio = area_pd / sum(area_pd);

%% 4. Generator data from data_g
% data_g columns:
% 1 bus, 2 Pmax, 3 Pmin, 4 ramp, 5 startup, 6 fuel_b,
% 7 minT, 8 H, 9 region.
data.gen.bus    = data_g(:, 1)';
data.gen.Pmax   = data_g(:, 2);
data.gen.Pmin   = data_g(:, 3);
data.gen.RU     = data_g(:, 4);
data.gen.RD     = data_g(:, 4);
data.gen.cSU    = data_g(:, 5);
data.gen.b      = data_g(:, 6);
data.gen.TU     = data_g(:, 7);
data.gen.TD     = data_g(:, 7);
data.gen.H      = data_g(:, 8);
data.gen.region = data_g(:, 9);

data.area_gen = cell(1, data.na);
for a = 1:data.na
    data.area_gen{a} = find(data.gen.region == a)';
end

% Fields missing from data.m, filled using the previous system defaults.
data.gen.a = zeros(data.ng, 1);
data.gen.c = 180 * ones(data.ng, 1);
data.gen.c(data.gen.Pmax < 500) = 300;
data.gen.c(data.gen.Pmax < 250) = 250;
data.gen.c(data.gen.Pmax < 150) = 200;
data.gen.c(data.gen.Pmax < 100) = 150;
data.gen.cSD   = data.gen.cSU;
data.gen.cR    = 20 * ones(data.ng, 1);
% Initial commitment snapshot from case 4 at hour 1
% (MAFCUC_results_4.mat, U_opt(:,1)); generator order follows data_g.
data.gen.u0    = [1; 0; 0; 1; 1; 1; 1; 1; 0; 1; 1; 1; ...
                  1; 1; 0; 1; 0; 1; 1; 0; 1; 0; 1; 0];
data.gen.P0    = data.gen.Pmin;
data.gen.Ton0  = data.gen.TU;
data.gen.Toff0 = data.gen.TD;

data.gen.Tg = 8 * ones(data.ng, 1);
data.gen.Tg(data.gen.Pmax <= 100) = 6;
data.gen.Tg(data.gen.Pmax <= 50)  = 4;
data.gen.Tg(data.gen.Pmax >= 300) = 8;

data.gen.Kg_raw = 15 * ones(data.ng, 1);
data.gen.Kg_raw(data.gen.Pmax <= 450) = 30;
data.gen.Kg_raw(data.gen.Pmax <= 300) = 25;
data.gen.Kg_raw(data.gen.Pmax <= 200) = 25;
data.gen.Kg_raw(data.gen.Pmax <= 100) = 20;
data.gen.Kg_raw(data.gen.Pmax <= 50)  = 15;
% data.gen.Kg_raw(data.gen.Pmax >= 300) = 30;
data.gen.Kg = data.gen.Kg_raw;

%% 5. Load profile and bus-level load
data.Pload_peak = 4000;
% data.load_coeff = [0.85, 0.80, 0.75, 0.73, 0.72, 0.75, 0.82, 0.92, ...
%                    1.00, 0.98, 0.96, 0.95, 0.96, 0.97, 0.98, 0.99, ...
%                    1.00, 0.98, 0.96, 0.94, 0.92, 0.90, 0.88, 0.86];
% data.load_coeff = [1.00, 0.80, 0.75, 0.73, 0.72, 0.75, 0.82, 0.92, ...
%                    1.00, 0.98, 0.96, 0.95, 0.96, 0.97, 0.98, 0.99, ...
%                    1.00, 0.98, 0.96, 0.94, 0.92, 0.90, 0.88, 0.86];
data.load_coeff = [0.71, 0.76, 0.72, 0.70, 0.69, 0.72, 0.75, 0.85, ...
                   0.87, 0.88, 0.90, 0.89, 0.90, 0.91, 0.90, 0.92, ...
                   0.91, 0.92, 0.90, 0.88, 0.86, 0.85, 0.83, 0.81];
data.load_coeff_full = data.load_coeff;
data.time_index = select_time_indices(data.nt, length(data.load_coeff_full), data.debug_time_index);
data.load_coeff = data.load_coeff_full(data.time_index);

data.area_peak = data.Pload_peak * data.area_load_ratio;
data.Pload = zeros(data.nt, data.na);
for a = 1:data.na
    data.Pload(:, a) = data.area_peak(a) * data.load_coeff';
end
data.Pload_total = sum(data.Pload, 2);

data.bus_load = zeros(data.nb, data.nt);
for a = 1:data.na
    buses_a = data.area_buses{a};
    pd_a = data_b(buses_a, 3);
    if sum(pd_a) > 0
        bus_weights = pd_a / sum(pd_a);
    else
        bus_weights = ones(length(buses_a), 1) / length(buses_a);
    end
    for t = 1:data.nt
        data.bus_load(buses_a, t) = data.Pload(t, a) * bus_weights;
    end
end

data.base_load.Pload = data.Pload;
data.base_load.Pload_total = data.Pload_total;
data.base_load.bus_load = data.bus_load;

%% 6. Renewable/wind data from data_r
% data_r columns: 1 bus, 2 capacity/baseMVA, 3 region.
data.wind.bus      = data_r(:, 1)';
data.wind.capacity = data_r(:, 2) * baseMVA;
data.wind.region   = data_r(:, 3)';
data.wind.nw       = size(data_r, 1);
data.wind.capacity_total = sum(data.wind.capacity);

data.wind_coeff = [0.56, 0.52, 0.60, 0.63, 0.59, 0.60, 0.64, 0.66, ...
                   0.62, 0.58, 0.52, 0.61, 0.69, 0.60, 0.54, 0.54, ...
                   0.53, 0.51, 0.49, 0.48, 0.44, 0.36, 0.36, 0.42];
data.wind_coeff_full = data.wind_coeff;
data.wind_coeff = data.wind_coeff_full(data.time_index);

data.Pwind_avail = zeros(data.nt, data.wind.nw);
for w = 1:data.wind.nw
    data.Pwind_avail(:, w) = data.wind.capacity(w) * data.wind_coeff';
end
data.Pwind_total = sum(data.Pwind_avail, 2);

data.wind.n_scen = 5;
data.wind.scenario_seed = 1;
data.wind.scenario_band = 0.10;
data.wind.scenario_prob = ones(1, data.wind.n_scen) / data.wind.n_scen;

data.Pwind_avail_scen = zeros(data.nt, data.wind.nw, data.wind.n_scen);
data.Pwind_avail_scen(:, :, 1) = data.Pwind_avail;
old_rng_state = rng;
rng(data.wind.scenario_seed);
for s = 2:data.wind.n_scen
    wind_factor = 1 + data.wind.scenario_band * (2 * rand(data.nt, data.wind.nw) - 1);
    data.Pwind_avail_scen(:, :, s) = max(0, data.Pwind_avail .* wind_factor);
end
rng(old_rng_state);
data.Pwind_total_scen = zeros(data.nt, data.wind.n_scen);
for s = 1:data.wind.n_scen
    data.Pwind_total_scen(:, s) = sum(data.Pwind_avail_scen(:, :, s), 2);
end

%% 7. Data center data from data_dc
% data_dc columns:
% 1 bus, 2 Pmax, 3 fixed_ratio, 4 GPU_FR_ratio, 5 spatial_FR_ratio,
% 6 time_sch_ratio, 7 spatial_sch_ratio, 8 region.
data.dc.bus = data_dc(:, 1)';
data.dc.Pmax = data_dc(:, 2);
data.dc.fixed_ratio = data_dc(:, 3);
data.dc.GPUM_ratio_by_dc = data_dc(:, 4);
data.dc.SPM_ratio_by_dc  = data_dc(:, 7);
data.dc.STM_ratio_by_dc  = data_dc(:, 6);
data.dc.SFM_ratio_by_dc  = data_dc(:, 5);
data.dc.region = data_dc(:, 8);

data.dc.dc_ratio   = mean(data.dc.fixed_ratio);
data.dc.GPUM_ratio = mean(data.dc.GPUM_ratio_by_dc);
data.dc.SPM_ratio  = mean(data.dc.SPM_ratio_by_dc);
data.dc.STM_ratio  = mean(data.dc.STM_ratio_by_dc);
data.dc.SFM_ratio  = mean(data.dc.SFM_ratio_by_dc);
data.dc.T_gpu = 0.1;
data.dc.K_gpu = 25;
% Fast SFM dynamics make the fixed 15% spatial-response capacity visible
% in the disturbed area's nadir without changing the SFM gain or ratio.
data.dc.T_sfm = 0.5;
data.dc.K_sfm =30;
data.dc.area_ratio = data.area_load_ratio;

% Data centers are additional loads. Their 24-hour profile follows the
% system load shape, scaled to stay between 60% and 80% of each DC capacity.
load_shape = data.load_coeff_full;
load_shape = (load_shape - min(load_shape)) / (max(load_shape) - min(load_shape));
data.dc.load_coeff_full = 0.60 + 0.20 * load_shape;
data.dc.load_coeff = data.dc.load_coeff_full(data.time_index);

data.dc.Pload_full = data.dc.load_coeff_full(:) * data.dc.Pmax(:).';
data.dc.Pload = data.dc.load_coeff(:) * data.dc.Pmax(:).';
data.dc.Pload_total = sum(data.dc.Pload, 2);
data.dc.Pload_area = zeros(data.nt, data.na);
data.dc.Pgpu_max = data.dc.Pload .* repmat(data.dc.GPUM_ratio_by_dc(:).', data.nt, 1);
%% ==============================================================
% 数据中心空间快速转移频率响应参数
% ==============================================================

ndc = length(data.dc.bus);

% 每个数据中心的SFM时间常数
data.dc.T_sfm_by_dc = ...
    data.dc.T_sfm * ones(ndc, 1);


% 数据中心调度前负荷的SFM最大可转移量
%
% data.dc.Pload维度：nt × ndc
% SFM_ratio_by_dc来自数据文件第5列，当前为15%
%
% 因此：
% Psfm_max(t,d) = 0.15 * Pload(t,d)
data.dc.Psfm_max = ...
    data.dc.Pload ...
    .* repmat( ...
        data.dc.SFM_ratio_by_dc(:).', ...
        data.nt, 1);

% SFM备用容量成本，单位：$/MW
% 暂时采用与普通备用相同的成本
data.dc.cR_sfm = 35;

% SFM源区域和允许转移关系在频率扰动比例确定后统一设置。
% 先给出保守默认值，后续根据 data.freq.dPL_ratio_area 覆盖。
data.dc.SFM_source_areas = [];
data.dc.SFM_source_area = [];
data.dc.K_sfm_by_dc = zeros(ndc, 1);
data.dc.SFM_allow = false(ndc, ndc);
%%
data.dc.K_gpu_by_dc = data.dc.K_gpu * ones(length(data.dc.bus), 1);
data.dc.cR_gpu = 35;

for d = 1:length(data.dc.bus)
    bus_d = data.dc.bus(d);
    area_d = data.dc.region(d);
    data.bus_load(bus_d, :) = data.bus_load(bus_d, :) + data.dc.Pload(:, d).';
    data.Pload(:, area_d) = data.Pload(:, area_d) + data.dc.Pload(:, d);
    data.dc.Pload_area(:, area_d) = data.dc.Pload_area(:, area_d) + data.dc.Pload(:, d);
end
data.Pload_total = sum(data.Pload, 2);

data.Pload_peak_base = data.Pload_peak;
base_total_full = data.Pload_peak_base * data.load_coeff_full(:);
data.Pload_peak = max(base_total_full + sum(data.dc.Pload_full, 2));
data.area_peak_with_dc = data.area_peak + 0.80 * accumarray(data.dc.region(:), data.dc.Pmax(:), [data.na, 1]).';

%% 8. MAFCUC network and frequency defaults
data.tieline.X12 = 0.08;
data.tieline.X23 = 0.08;
data.tieline.X13 = 1000;

data.tieline.dynamic_impedance_multiplier = 5;
% Legacy diagnostic only; build_tieline_model does not use this field.
data.tieline.dynamic_strength_scale = ...
    pi * baseMVA / data.tieline.dynamic_impedance_multiplier;
data.tieline.Fmax_12 = 2.0 * min(data.area_peak_with_dc(1), data.area_peak_with_dc(2));
data.tieline.Fmax_23 = 2.0 * min(data.area_peak_with_dc(2), data.area_peak_with_dc(3));
data.tieline.Fmax_13 = 2.0 * min(data.area_peak_with_dc(1), data.area_peak_with_dc(3));

data.freq.L  = 30;
% 15 BP segments of length 2 s; the polynomial order m is configured
% independently below, and Q/J/V all adapt automatically when m changes.
data.freq.ls = 2;
data.freq.m  = 8;
% V矩阵De Casteljau二分细化等级：0为原始控制点，1--4逐级提高精度。
% V会根据当前m自动生成，无需在调整m时手工修改矩阵。
data.freq.V_refinement_level = 1;
data.freq.df_max     = 0.5;
data.freq.df_qss_max = 0.3;
data.freq.rocof_max  = 0.5;
data.freq.df_db = 0.01;
data.freq.eps_df_cont = 1e-3;
data.freq.eps_pfr_cont = 1e-3;
data.freq.eps_gpu_cont = 1e-3;
data.freq.eps_sfm_cont = 1e-3;
% Load damping is kept at the user's original value.  Inter-area oscillation
% frequency and relative amplitude are corrected through the physical
% tie-line synchronizing coefficient above, not by artificially increasing D.
data.freq.kL = 0.01;
data.freq.dPL_ratio = 0.01;
data.freq.dPL_ratio_area = [0.0 0.0 0.15];  % Area 1/2/3 disturbance ratios.
data.freq.min_online_reserve_ratio = 0.01;
data.freq.use_droop_initial_reserve = true;
data.freq.droop_initial_reserve_factor = 0.1;
data.freq.area_sync_reserve_ratio = 0;

if isfield(data.freq, 'dPL_ratio_area')
    data.freq.dPL_ratio_area = data.freq.dPL_ratio_area(:).';
else
    data.freq.dPL_ratio_area = repmat(data.freq.dPL_ratio, 1, data.na);
end
if numel(data.freq.dPL_ratio_area) ~= data.na
    error('system_data:dPL_ratio_area', ...
        'data.freq.dPL_ratio_area must have %d elements, one for each area.', data.na);
end
if any(data.freq.dPL_ratio_area < 0)
    error('system_data:dPL_ratio_area', ...
        'data.freq.dPL_ratio_area must be nonnegative.');
end

% SFM响应源区域：所有含数据中心的区域都允许作为SFM转出源。
% 频率扰动仍由 data.freq.dPL_ratio_area 单独定义；源区域不再受
% “仅扰动区域可转出”的限制。
dc_region = data.dc.region(:);
sfm_source_areas = unique(dc_region, 'stable').';
data.dc.SFM_source_areas = sfm_source_areas;
if isempty(sfm_source_areas)
    data.dc.SFM_source_area = [];
else
    data.dc.SFM_source_area = sfm_source_areas(1);
end

source_dc_mask = ismember(dc_region, sfm_source_areas);
data.dc.K_sfm_by_dc = data.dc.K_sfm * double(source_dc_mask);
data.dc.SFM_allow = ...
    bsxfun(@and, source_dc_mask, dc_region.' ~= dc_region);
data.dc.SFM_allow = logical(data.dc.SFM_allow);

% QSS约束使用论文式18。由于外部机组数据没有给出统一单位下的Kg，
% 这里保留原始Kg，并按全在线QSS可行性做统一尺度校准。
qss_headroom = data.freq.df_qss_max - data.freq.df_db;
qss_raw_gen = qss_headroom * sum(data.gen.Kg_raw);
qss_scale_req = 1;
for t = 1:data.nt
    qss_required = sum(data.freq.dPL_ratio_area .* data.Pload(t, :));
    qss_damping = data.freq.kL * data.freq.df_qss_max * sum(data.Pload(t, :));
    qss_shortfall = max(0, qss_required - qss_damping);
    if qss_raw_gen > 0
        qss_scale_req = max(qss_scale_req, qss_shortfall / qss_raw_gen);
    end
end
data.freq.Kg_scale = max(1, 1.02 * qss_scale_req);
data.gen.Kg = data.gen.Kg_raw * data.freq.Kg_scale;

%% 9. Derived data
data.area_H = zeros(data.na, 1);
data.area_Tg = zeros(data.na, 1);
data.area_Kg = zeros(data.na, 1);
data.area_cap = zeros(data.na, 1);
for a = 1:data.na
    gen_idx = data.area_gen{a};
    Pmax_a = data.gen.Pmax(gen_idx);
    data.area_H(a) = sum(Pmax_a .* data.gen.H(gen_idx)) / sum(Pmax_a);
    data.area_Tg(a) = sum(Pmax_a .* data.gen.Tg(gen_idx)) / sum(Pmax_a);
    data.area_Kg(a) = sum(Pmax_a) / sum(Pmax_a ./ data.gen.Kg(gen_idx));
    data.area_cap(a) = sum(Pmax_a);
end

data.total_cap = sum(data.gen.Pmax);
data.wind_penetration = data.wind.capacity_total / data.Pload_peak;
data.freq.ns = ceil(data.freq.L / data.freq.ls);
%% 调度层

% 一个调度时段的长度，单位：小时
data.delta_t = 1;

% Penalty costs from the MAFCUC objective (12), in $/MWh.
data.cost.wind_curtailment = 80;
data.cost.load_shedding = 150;

% 时间转移成本，单位：$/MWh
data.dc.cSTM = 25;

% 空间转移成本，单位：$/MWh
data.dc.cSPM = 25;

% 延迟任务最长允许恢复时间，单位：调度时段
% nt=24且每时段1小时，则4表示最多延迟4小时
data.dc.H_delay = 4 * ones(length(data.dc.bus), 1);

% 是否让调度后的区域负荷影响频率扰动
data.dc.couple_scheduled_load_to_frequency = true;
%% 10. Consistency checks
assert(size(data.raw.bus, 2) == 13, 'Raw bus data should keep all 13 columns.');
assert(size(data.raw.branch, 2) == 13, 'Raw branch data should keep all 13 columns.');
assert(length(data.gen.bus) == data.ng, 'Generator bus count mismatch.');
assert(length(data.gen.Pmax) == data.ng, 'Pmax dimension mismatch.');
assert(length(data.gen.Pmin) == data.ng, 'Pmin dimension mismatch.');
assert(all(data.gen.Pmin <= data.gen.Pmax), 'Pmin should not exceed Pmax.');
assert(sum(cellfun(@length, data.area_gen)) == data.ng, 'Area generator count mismatch.');
assert(all(ismember(data.gen.bus, data_b(:, 1))), 'Generator bus is missing from data_b.');
assert(all(ismember(data.wind.bus, data_b(:, 1))), 'Wind bus is missing from data_b.');
assert(length(data.wind.bus) == data.wind.nw, 'Wind bus count mismatch.');
assert(size(data.Pwind_avail, 1) == data.nt, 'Wind time dimension mismatch.');
assert(size(data.Pwind_avail, 2) == data.wind.nw, 'Wind plant count mismatch.');
assert(size(data.Pwind_avail_scen, 1) == data.nt, 'Wind scenario time dimension mismatch.');
assert(size(data.Pwind_avail_scen, 2) == data.wind.nw, 'Wind scenario plant count mismatch.');
assert(size(data.Pwind_avail_scen, 3) == data.wind.n_scen, 'Wind scenario count mismatch.');
assert(abs(sum(data.wind.scenario_prob) - 1) < 1e-10, 'Wind scenario probabilities must sum to 1.');
assert(max(abs(data.Pwind_avail_scen(:, :, 1) - data.Pwind_avail), [], 'all') < 1e-10, ...
    'Wind scenario 1 should match the base wind profile.');
assert(length(data.load_coeff) == data.nt, 'Load profile length mismatch.');
assert(size(data.Pload, 1) == data.nt, 'Area load time dimension mismatch.');
assert(size(data.Pload, 2) == data.na, 'Area load count mismatch.');
assert(all(data.dc.load_coeff_full >= 0.60 - 1e-10) && all(data.dc.load_coeff_full <= 0.80 + 1e-10), ...
    'Data center load coefficient should stay within 60%-80%.');
assert(all(data.dc.Pgpu_max(:) >= -1e-10) && all(data.dc.Pgpu_max(:) <= data.dc.Pload(:) + 1e-10), ...
    'GPU frequency-response capacity should stay between 0 and data center load.');
% assert(all(data.dc.K_gpu_by_dc == 20), 'GPU frequency-response gain should be 20 MW/Hz for every data center.');
assert(max(abs(sum(data.bus_load, 1)' - data.Pload_total)) < 1e-6, ...
    'Bus load and area load totals should match after adding data centers.');
assert(data.cost.wind_curtailment >= 0 && data.cost.load_shedding >= 0, ...
    'Wind curtailment and load shedding penalty costs must be nonnegative.');

param_names = {'Pmax', 'Pmin', 'a', 'b', 'c', 'cSU', 'cSD', 'RU', 'RD', ...
               'TU', 'TD', 'u0', 'P0', 'H', 'Tg', 'Kg', 'cR'};
for k = 1:length(param_names)
    val = data.gen.(param_names{k});
    assert(length(val) == data.ng, ...
        sprintf('Generator parameter %s dimension mismatch: expected %d, got %d.', ...
        param_names{k}, data.ng, length(val)));
end

fprintf('System data loaded:\n');
fprintf('  Buses: %d\n', data.nb);
fprintf('  Generators: %d (Area1: %d, Area2: %d, Area3: %d)\n', ...
    data.ng, length(data.area_gen{1}), length(data.area_gen{2}), length(data.area_gen{3}));
fprintf('  Total generation capacity: %.0f MW\n', data.total_cap);
fprintf('  Peak load: %.0f MW\n', data.Pload_peak);
fprintf('  Wind plants: %d, total capacity: %.0f MW (penetration: %.1f%%)\n', ...
    data.wind.nw, data.wind.capacity_total, data.wind_penetration * 100);
fprintf('  Raw branch rows retained: %d\n', size(data.raw.branch, 1));
fprintf('  Data centers: %d, total capacity: %.0f MW, load range: %.0f%%-%.0f%%\n', ...
    length(data.dc.bus), sum(data.dc.Pmax), ...
    min(data.dc.load_coeff_full) * 100, max(data.dc.load_coeff_full) * 100);
fprintf('  Data validation passed.\n');

end

function idx = select_time_indices(nt, profile_len, start_idx)

if nt < 1 || nt ~= floor(nt)
    error('system_data:InvalidTimeCount', 'data.nt must be a positive integer.');
end
if nt > profile_len
    error('system_data:InvalidTimeCount', ...
        'data.nt=%d exceeds the available profile length %d.', nt, profile_len);
end
if nargin < 3 || isempty(start_idx)
    start_idx = 1;
end
start_idx = max(1, min(profile_len, round(start_idx)));
last_idx = start_idx + nt - 1;
if last_idx > profile_len
    start_idx = profile_len - nt + 1;
    last_idx = profile_len;
end
idx = start_idx:last_idx;
end
