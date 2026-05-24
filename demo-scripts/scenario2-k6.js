import http from "k6/http";
import { check, sleep } from "k6";

const targetUrl = (__ENV.TARGET_URL || "https://app.vuongdevops.io.vn").replace(/\/$/, "");
const warmupVus = Number(__ENV.WARMUP_VUS || 20);
const targetVus = Number(__ENV.TARGET_VUS || 180);
const latencyThresholdMs = Number(__ENV.LATENCY_THRESHOLD_MS || 20000);
const failedRateThreshold = Number(__ENV.FAILED_RATE_THRESHOLD || 0.9);

export const options = {
  stages: [
    { duration: __ENV.WARMUP_DURATION || "30s", target: warmupVus },
    { duration: __ENV.RAMP_DURATION || "60s", target: targetVus },
    { duration: __ENV.HOLD_DURATION || "3m", target: targetVus },
    { duration: __ENV.RAMPDOWN_DURATION || "60s", target: 0 }
  ],
  thresholds: {
    http_req_failed: [`rate<${failedRateThreshold}`],
    http_req_duration: [`p(95)<${latencyThresholdMs}`]
  }
};

const routes = [
  "/",
  "/product/OLJCESPC7Z",
  "/product/66VCHSJNUP",
  "/product/1YMWWN1N4O"
];

export default function () {
  const route = routes[Math.floor(Math.random() * routes.length)];
  const response = http.get(`${targetUrl}${route}`, {
    tags: {
      scenario: "keda-scenario-2",
      route
    }
  });

  check(response, {
    "status is 2xx or 3xx": (r) => r.status >= 200 && r.status < 400
  });

  sleep(Math.random() * 0.8 + 0.2);
}
