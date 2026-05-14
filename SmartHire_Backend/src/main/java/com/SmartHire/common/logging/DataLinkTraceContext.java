package com.SmartHire.common.logging;

import java.util.UUID;

final class DataLinkTraceContext {

  private static final ThreadLocal<TraceState> TRACE_STATE = new ThreadLocal<>();

  private DataLinkTraceContext() {}

  static TraceScope enter() {
    TraceState state = TRACE_STATE.get();
    boolean root = false;
    if (state == null) {
      state = new TraceState(newTraceId());
      TRACE_STATE.set(state);
      root = true;
    }
    int depth = state.depth;
    state.depth++;
    return new TraceScope(state.traceId, depth, root);
  }

  static void exit(TraceScope scope) {
    TraceState state = TRACE_STATE.get();
    if (state == null) {
      return;
    }
    state.depth = Math.max(0, state.depth - 1);
    if (scope.root() || state.depth == 0) {
      TRACE_STATE.remove();
    }
  }

  private static String newTraceId() {
    return UUID.randomUUID().toString().replace("-", "").substring(0, 16);
  }

  private static final class TraceState {
    private final String traceId;
    private int depth;

    private TraceState(String traceId) {
      this.traceId = traceId;
    }
  }

  record TraceScope(String traceId, int depth, boolean root) {}
}
