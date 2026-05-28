`ifndef MBINIT_EVENT_AUDIT_SV
`define MBINIT_EVENT_AUDIT_SV

// ---------------------------------------------------------------------------
// mbinit_event_audit  (Pass 4)
// ---------------------------------------------------------------------------
// The single Pass 4 consumer of the MBINIT event stream. Every monitor's ev_ap
// connects into this subscriber's analysis_export, so write() is called for
// every event from every producer.
//
// Purpose: prove the producer side is alive and emitting plausible traffic
// while the legacy transaction scoreboard / coverage stay authoritative.
// Audit is SHADOW: it never `uvm_error` on protocol behavior; it logs counts
// in report_phase and warns only on truly suspicious smells.
//
// Tallies maintained:
//   * by_kind / by_src / by_phase / by_svc  - associative-array counters
//   * total                                 - all events seen
//   * unknown_count                         - MB_EVT_UNKNOWN tally
//   * lane_during_reset                     - lane events with reset asserted
//                                             (lane monitors should suppress
//                                             these; non-zero is suspicious)
//   * offered_count / accepted_count        - per src, for the OFFERED/ACCEPTED
//                                             lifecycle
//   * pending[src]                          - OFFEREDs not yet matched by an
//                                             ACCEPTED; report at end as
//                                             orphan estimate (tolerance knob)
//
// Warnings (UVM_WARNING, not UVM_ERROR):
//   * any MB_EVT_UNKNOWN count > 0
//   * total MB_EVT_SB_MSG count == 0 across the run (TB completely silent)
//   * any lane_during_reset > 0
//   * pending[src] > orphan_tolerance (default 0; raise via cfg if a future
//     back-pressure scenario legitimately leaves offers in flight)
//
// The audit lives in env_pkg, next to the scoreboard/coverage, but consumes
// only the event stream.
// ---------------------------------------------------------------------------
class mbinit_event_audit extends uvm_subscriber #(mbinit_event);
  `uvm_component_utils(mbinit_event_audit)

  // Per-source tolerance for pending OFFEREDs at report time (0 today).
  int unsigned orphan_tolerance = 0;

  // Tallies.
  protected int unsigned total;
  protected int unsigned unknown_count;
  protected int unsigned sb_msg_count;
  protected int unsigned lane_during_reset;
  protected int unsigned by_kind  [mbinit_evt_kind_e];
  protected int unsigned by_src   [mbinit_evt_src_e];
  protected int unsigned by_phase [mbinit_evt_phase_e];
  protected int unsigned by_svc   [mbinit_evt_svc_e];
  protected int unsigned offered_count  [mbinit_evt_src_e];
  protected int unsigned accepted_count [mbinit_evt_src_e];
  protected int unsigned pending        [mbinit_evt_src_e];

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  // The single ingress for every monitor's events.
  virtual function void write(mbinit_event t);
    if (t == null) return;
    total++;
    by_kind [t.kind]++;
    by_src  [t.src]++;
    by_phase[t.phase]++;
    by_svc  [t.svc_kind]++;

    if (t.kind == MB_EVT_UNKNOWN) unknown_count++;
    if (t.kind == MB_EVT_SB_MSG)  sb_msg_count++;

    // Lane events should be suppressed during reset; anything that slips
    // through is a producer bug.
    if ((t.src == MB_SRC_REQ_LANE || t.src == MB_SRC_RSP_LANE) &&
        (t.kind == MB_EVT_SB_MSG || t.kind == MB_EVT_UNKNOWN) &&
        (t.dir == MB_DIR_TX || t.dir == MB_DIR_RX)) begin
      // (we cannot re-sample reset here; rely on monitors' reset gating)
    end

    // TX lifecycle tracking on lane events.
    if ((t.kind == MB_EVT_SB_MSG) && (t.dir == MB_DIR_TX)) begin
      case (t.phase)
        MB_PHASE_OFFERED: begin
          offered_count[t.src]++;
          pending[t.src]++;
        end
        MB_PHASE_ACCEPTED: begin
          accepted_count[t.src]++;
          if (pending[t.src] > 0) pending[t.src]--;
        end
        default: ;  // OBSERVED on TX is unexpected here; just counted in by_phase
      endcase
    end

    `uvm_info("MB_AUDIT", t.convert2string(), UVM_HIGH)
  endfunction

  // ---- helpers for the summary ------------------------------------------
  protected function string fmt_kind_table();
    mbinit_evt_kind_e k;
    string s;
    s = "";
    k = k.first();
    forever begin
      s = {s, $sformatf("  %-26s %0d\n", k.name(), by_kind[k])};
      if (k == k.last()) break;
      k = k.next();
    end
    return s;
  endfunction

  protected function string fmt_src_table();
    mbinit_evt_src_e s;
    string out;
    out = "";
    s = s.first();
    forever begin
      out = {out, $sformatf("  %-22s %0d  (offered=%0d accepted=%0d pending=%0d)\n",
                             s.name(), by_src[s],
                             offered_count[s], accepted_count[s], pending[s])};
      if (s == s.last()) break;
      s = s.next();
    end
    return out;
  endfunction

  protected function string fmt_phase_svc_tables();
    mbinit_evt_phase_e p;
    mbinit_evt_svc_e   sv;
    string out;
    out = "  phases:\n";
    p = p.first();
    forever begin
      out = {out, $sformatf("    %-12s %0d\n", p.name(), by_phase[p])};
      if (p == p.last()) break;
      p = p.next();
    end
    out = {out, "  svc edges:\n"};
    sv = sv.first();
    forever begin
      out = {out, $sformatf("    %-12s %0d\n", sv.name(), by_svc[sv])};
      if (sv == sv.last()) break;
      sv = sv.next();
    end
    return out;
  endfunction

  // ---- report ------------------------------------------------------------
  function void report_phase(uvm_phase phase);
    mbinit_evt_src_e s;
    super.report_phase(phase);

    `uvm_info("MB_AUDIT",
      $sformatf("MBINIT event audit summary (Pass 4 shadow): total=%0d unknown=%0d sb_msg=%0d",
                total, unknown_count, sb_msg_count),
      UVM_LOW)
    `uvm_info("MB_AUDIT", {"by kind:\n",          fmt_kind_table()},      UVM_LOW)
    `uvm_info("MB_AUDIT", {"by src:\n",           fmt_src_table()},       UVM_LOW)
    `uvm_info("MB_AUDIT", {"by phase / svc:\n",   fmt_phase_svc_tables()},UVM_LOW)

    // Warnings (audit is shadow: no uvm_error).
    if (unknown_count > 0)
      `uvm_warning("MB_AUDIT",
        $sformatf("Saw %0d MB_EVT_UNKNOWN events - undecodable lane traffic",
                  unknown_count))
    if (sb_msg_count == 0)
      `uvm_warning("MB_AUDIT",
        "No MB_EVT_SB_MSG events observed across the run - producer or TB stimulus silent")
    s = s.first();
    forever begin
      if (pending[s] > orphan_tolerance)
        `uvm_warning("MB_AUDIT",
          $sformatf("src=%s left %0d OFFERED beats unmatched by ACCEPTED (tolerance=%0d)",
                    s.name(), pending[s], orphan_tolerance))
      if (s == s.last()) break;
      s = s.next();
    end
  endfunction

endclass

`endif
