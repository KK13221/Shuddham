// MQTT topic layout (see FIRMWARE.md):
//   <prefix>/<deviceId>/telemetry   device -> server   {"tds":42,"tdsIn":380,"temp":26.5}
//   <prefix>/<deviceId>/status      device -> server   "online" | "offline" (retained, also the LWT)
//   <prefix>/<deviceId>/cmd         server -> device   {"cmd":"identify"} | {"cmd":"factory_reset"}

export function makeTopics(prefix) {
  const clean = prefix.replace(/\/+$/, '');
  return {
    telemetry: (id) => `${clean}/${id}/telemetry`,
    status: (id) => `${clean}/${id}/status`,
    cmd: (id) => `${clean}/${id}/cmd`,
    /** Returns { deviceId, kind } for a device topic, else null. */
    parse(topic) {
      if (!topic.startsWith(clean + '/')) return null;
      const rest = topic.slice(clean.length + 1).split('/');
      if (rest.length !== 2) return null;
      const [deviceId, kind] = rest;
      if (!['telemetry', 'status', 'cmd'].includes(kind)) return null;
      return { deviceId, kind };
    },
  };
}

/** A device may publish only telemetry/status on its own topics. */
export function canPublish(topics, deviceId, topic) {
  const t = topics.parse(topic);
  return !!t && t.deviceId === deviceId && (t.kind === 'telemetry' || t.kind === 'status');
}

/** A device may subscribe only to its own command topic. */
export function canSubscribe(topics, deviceId, topic) {
  return topic === topics.cmd(deviceId);
}
