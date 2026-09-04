import { mkdir, rm, writeFile } from "node:fs/promises";
import { join } from "node:path";

const width = 960;
const height = 600;
const fps = 30;
const duration = 16;
const frameDirectory = new URL("./frames/", import.meta.url);

const clamp = (value, minimum = 0, maximum = 1) => Math.min(maximum, Math.max(minimum, value));
const mix = (from, to, amount) => from + (to - from) * amount;
const smooth = (from, to, value) => {
    const amount = clamp((value - from) / (to - from));
    return amount * amount * (3 - 2 * amount);
};
const smoother = (from, to, value) => {
    const amount = clamp((value - from) / (to - from));
    return amount ** 3 * (amount * (amount * 6 - 15) + 10);
};
const escapeXML = value => String(value)
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;");

function stopwatchTime(time) {
    const centiseconds = Math.max(0, Math.floor(time * 100));
    const minutes = Math.floor(centiseconds / 6000);
    const seconds = Math.floor(centiseconds / 100) % 60;
    const fraction = centiseconds % 100;
    return `${String(minutes).padStart(2, "0")}:${String(seconds).padStart(2, "0")}.${String(fraction).padStart(2, "0")}`;
}

function compactTime(time) {
    const totalSeconds = Math.max(0, Math.floor(time));
    return `${String(Math.floor(totalSeconds / 60)).padStart(2, "0")}:${String(totalSeconds % 60).padStart(2, "0")}`;
}

function cursorPath(time) {
    const points = [
        [0.00, 785, 510],
        [0.70, 925, 305],
        [1.15, 925, 305],
        [2.15, 835, 440],
        [2.80, 672, 211],
        [3.20, 672, 211],
        [6.55, 672, 211],
        [7.10, 672, 211],
        [8.15, 807, 211],
        [9.20, 807, 211],
        [10.30, 860, 460],
        [11.35, 505, 455],
        [16.00, 505, 455],
    ];

    for (let index = 0; index < points.length - 1; index += 1) {
        const from = points[index];
        const to = points[index + 1];
        if (time <= to[0]) {
            const amount = smooth(from[0], to[0], time);
            return [mix(from[1], to[1], amount), mix(from[2], to[2], amount)];
        }
    }
    return points.at(-1).slice(1);
}

function clickPulse(time, center) {
    const delta = Math.abs(time - center);
    if (delta > 0.38) return "";
    const progress = clamp(delta / 0.38);
    const radius = mix(9, 31, progress);
    return `<circle cx="0" cy="0" r="${radius.toFixed(2)}" fill="none" stroke="#7CFF8A" stroke-width="${mix(3, 0.5, progress).toFixed(2)}" opacity="${(1 - progress).toFixed(2)}"/>`;
}

function headline(time) {
    if (time < 2.25) return ["Meet Pomotimer.", "Your focus timer, one hover away."];
    if (time < 6.55) return ["Start instantly.", "A precise stopwatch without the clutter."];
    if (time < 8.35) return ["Pause with a click.", "Your elapsed time stays right where you left it."];
    if (time < 10.35) return ["Reset. Ready.", "Begin the next session whenever you are."];
    return ["Stay in your flow.", "Pomotimer keeps time—and stays out of the way."];
}

function row(y, icon, title, selected) {
    return `
        <g transform="translate(0 ${y})">
            <text x="24" y="5" class="symbol" font-size="17">${icon}</text>
            <text x="51" y="5" class="ui" font-size="14" fill="#F1F4F2">${title}</text>
            <circle cx="252" cy="0" r="7" fill="${selected ? "#52CF61" : "none"}" stroke="${selected ? "#52CF61" : "#7A817E"}" stroke-width="1.5"/>
            ${selected ? '<path d="M248.5 0 l2.4 2.6 4.6 -5.5" fill="none" stroke="#102113" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round"/>' : ""}
        </g>`;
}

function renderFrame(time) {
    const opening = smoother(1.10, 2.25, time);
    const autoHide = smoother(12.45, 14.10, time);
    const desktopProgress = smoother(9.75, 11.15, time);
    const expansion = opening * (1 - autoHide);
    const showcaseX = mix(902, 590, opening);
    const showcaseY = mix(224, 50, opening);
    const showcaseWidth = mix(58, 300, opening);
    const showcaseHeight = mix(152, 500, opening);
    const desktopX = mix(831, 874, autoHide);
    const desktopY = mix(188, 224, autoHide);
    const desktopWidth = mix(75, 32, autoHide);
    const desktopHeight = mix(125, 86, autoHide);
    const panelX = mix(showcaseX, desktopX, desktopProgress);
    const panelY = mix(showcaseY, desktopY, desktopProgress);
    const panelWidth = mix(showcaseWidth, desktopWidth, desktopProgress);
    const panelHeight = mix(showcaseHeight, desktopHeight, desktopProgress);
    const contentOpacity = smoother(1.45, 2.18, time) * (1 - smoother(12.55, 13.52, time));
    const tabOpacity = Math.max(1 - smoother(1.12, 1.66, time), smoother(13.16, 13.94, time));
    const desktopElapsed = Math.max(0, time - 10.72);
    const desktopRunning = time >= 10.72;
    const running = (time >= 3.10 && time < 7.08) || desktopRunning;
    const paused = time >= 7.08 && time < 9.18;
    const elapsed = desktopRunning ? desktopElapsed : time < 3.10 ? 0 : Math.min(time - 3.10, 3.98);
    const display = desktopRunning ? stopwatchTime(desktopElapsed) : time >= 9.18 ? "00:00.00" : stopwatchTime(elapsed);
    const collapsedDisplay = desktopRunning ? compactTime(desktopElapsed) : "00:00";
    const status = running ? "Running" : paused ? "Paused" : "Ready";
    const primaryLabel = running ? "Pause" : "Start";
    const [cursorX, cursorY] = cursorPath(time);
    const cursorOpacity = smooth(0.25, 0.55, time) * (1 - smooth(11.30, 11.80, time));
    const [title, subtitle] = headline(time);
    const titleFade = smooth(0.15, 0.65, time) * (1 - smooth(10.00, 10.65, time));
    const lift = 1 + 0.018 * smooth(2.8, 3.35, time) * (1 - smooth(7.1, 7.55, time));
    const glow = running ? 0.34 + Math.sin(time * 4) * 0.06 : 0.16;
    const orbShift = Math.sin(time * 0.55) * 24;
    const resetPressed = Math.abs(time - 9.10) < 0.12;
    const startPressed = Math.abs(time - 3.04) < 0.12 || Math.abs(time - 7.02) < 0.12;
    const meetingOpacity = smoother(9.85, 10.78, time);
    const meetingScale = mix(0.86, 1, smoother(9.75, 11.15, time));
    const autoHideLabelOpacity = smoother(11.65, 12.20, time) * (1 - smoother(14.10, 14.52, time));
    const endCardOpacity = smooth(14.20, 14.90, time);
    const panelCornerRadius = mix(mix(14, 18, opening), mix(5, 8, autoHide), desktopProgress);

    return `<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" width="${width}" height="${height}" viewBox="0 0 ${width} ${height}">
    <defs>
        <linearGradient id="background" x1="0" y1="0" x2="1" y2="1">
            <stop offset="0" stop-color="#0A1010"/>
            <stop offset="0.48" stop-color="#13201B"/>
            <stop offset="1" stop-color="#07100D"/>
        </linearGradient>
        <radialGradient id="orbGreen">
            <stop offset="0" stop-color="#49DA70" stop-opacity="0.30"/>
            <stop offset="1" stop-color="#49DA70" stop-opacity="0"/>
        </radialGradient>
        <radialGradient id="orbViolet">
            <stop offset="0" stop-color="#7770FF" stop-opacity="0.23"/>
            <stop offset="1" stop-color="#7770FF" stop-opacity="0"/>
        </radialGradient>
        <linearGradient id="panel" x1="0" y1="0" x2="1" y2="1">
            <stop offset="0" stop-color="#1B201E"/>
            <stop offset="1" stop-color="#0E1210"/>
        </linearGradient>
        <linearGradient id="button" x1="0" y1="0" x2="1" y2="1">
            <stop offset="0" stop-color="#59D969"/>
            <stop offset="1" stop-color="#3FB651"/>
        </linearGradient>
        <linearGradient id="desktopWallpaper" x1="0" y1="0" x2="1" y2="1">
            <stop offset="0" stop-color="#172B38"/>
            <stop offset="0.52" stop-color="#24463E"/>
            <stop offset="1" stop-color="#101A27"/>
        </linearGradient>
        <filter id="shadow" x="-60%" y="-60%" width="220%" height="240%">
            <feDropShadow dx="0" dy="24" stdDeviation="28" flood-color="#000000" flood-opacity="0.55"/>
            <feDropShadow dx="0" dy="5" stdDeviation="8" flood-color="#000000" flood-opacity="0.36"/>
        </filter>
        <filter id="softBlur"><feGaussianBlur stdDeviation="36"/></filter>
        <filter id="textShadow"><feDropShadow dx="0" dy="2" stdDeviation="4" flood-opacity="0.35"/></filter>
        <clipPath id="panelClip"><rect x="0" y="0" width="300" height="500" rx="18"/></clipPath>
        <clipPath id="meetingClip"><rect x="54" y="50" width="852" height="500" rx="17"/></clipPath>
        <style>
            .display { font-family: "SF Pro Rounded", "Helvetica Neue", sans-serif; font-variant-numeric: tabular-nums; }
            .ui { font-family: "SF Pro Display", "Helvetica Neue", sans-serif; }
            .symbol { font-family: "Apple Symbols", "Arial Unicode MS", sans-serif; }
        </style>
    </defs>

    <rect width="960" height="600" fill="url(#background)"/>
    <circle cx="${720 + orbShift}" cy="80" r="310" fill="url(#orbGreen)" filter="url(#softBlur)"/>
    <circle cx="${120 - orbShift * 0.6}" cy="560" r="300" fill="url(#orbViolet)" filter="url(#softBlur)"/>
    <path d="M-40 490 C190 410 290 610 540 520 S830 380 1030 460" fill="none" stroke="#FFFFFF" stroke-opacity="0.035" stroke-width="2"/>
    <path d="M-30 515 C210 430 330 635 560 540 S830 410 1030 485" fill="none" stroke="#FFFFFF" stroke-opacity="0.025" stroke-width="1"/>

    <g opacity="${meetingOpacity.toFixed(3)}" transform="translate(480 300) scale(${meetingScale.toFixed(4)}) translate(-480 -300)" filter="url(#shadow)">
        <rect x="42" y="38" width="876" height="524" rx="24" fill="#090D0C" stroke="#FFFFFF" stroke-opacity="0.16"/>
        <rect x="54" y="50" width="852" height="500" rx="17" fill="url(#desktopWallpaper)"/>
        <g clip-path="url(#meetingClip)">
            <circle cx="195" cy="165" r="220" fill="#5EE07B" fill-opacity="0.08"/>
            <circle cx="768" cy="460" r="260" fill="#6D72E9" fill-opacity="0.10"/>

            <rect x="54" y="50" width="852" height="27" fill="#EEF3F0" fill-opacity="0.90"/>
            <text x="70" y="69" class="ui" font-size="13" font-weight="700" fill="#17201C">●</text>
            <text x="89" y="69" class="ui" font-size="11" font-weight="700" fill="#17201C">Pomotimer</text>
            <text x="155" y="69" class="ui" font-size="11" fill="#26312C">File</text>
            <text x="181" y="69" class="ui" font-size="11" fill="#26312C">Edit</text>
            <text x="209" y="69" class="ui" font-size="11" fill="#26312C">View</text>
            <text x="885" y="69" text-anchor="end" class="ui" font-size="11" fill="#26312C">Wed 10:32 AM</text>

            <g filter="url(#textShadow)">
                <rect x="104" y="101" width="682" height="373" rx="15" fill="#101614" stroke="#FFFFFF" stroke-opacity="0.13"/>
                <rect x="104" y="101" width="682" height="40" rx="15" fill="#1A211E"/>
                <rect x="104" y="126" width="682" height="15" fill="#1A211E"/>
                <circle cx="124" cy="121" r="4.5" fill="#FF6259"/>
                <circle cx="140" cy="121" r="4.5" fill="#FFC04F"/>
                <circle cx="156" cy="121" r="4.5" fill="#53CE64"/>
                <text x="180" y="126" class="ui" font-size="12" font-weight="650" fill="#E9EDEB">Weekly focus session</text>
                <rect x="624" y="109" width="140" height="23" rx="11.5" fill="#52CF61" fill-opacity="0.12"/>
                <circle cx="640" cy="120.5" r="3.5" fill="#52CF61"/>
                <text x="651" y="125" class="ui" font-size="10" font-weight="600" fill="#9FE5A7">Meeting in progress</text>

                <rect x="122" y="157" width="154" height="116" rx="10" fill="#293632"/>
                <circle cx="199" cy="207" r="22" fill="#5F79D9"/><text x="199" y="215" text-anchor="middle" class="ui" font-size="19" font-weight="650" fill="#FFFFFF">A</text>
                <rect x="290" y="157" width="154" height="116" rx="10" fill="#302D3D"/>
                <circle cx="367" cy="207" r="22" fill="#9A6DCC"/><text x="367" y="215" text-anchor="middle" class="ui" font-size="19" font-weight="650" fill="#FFFFFF">M</text>
                <rect x="458" y="157" width="154" height="116" rx="10" fill="#3A3128"/>
                <circle cx="535" cy="207" r="22" fill="#D48653"/><text x="535" y="215" text-anchor="middle" class="ui" font-size="19" font-weight="650" fill="#FFFFFF">S</text>
                <rect x="626" y="157" width="142" height="116" rx="10" fill="#263737"/>
                <circle cx="697" cy="207" r="22" fill="#45A5A1"/><text x="697" y="215" text-anchor="middle" class="ui" font-size="19" font-weight="650" fill="#FFFFFF">Y</text>

                <rect x="122" y="290" width="646" height="116" rx="10" fill="#19211E"/>
                <text x="445" y="332" text-anchor="middle" class="ui" font-size="18" font-weight="650" fill="#E7ECE9">Deep-work discussion</text>
                <text x="445" y="359" text-anchor="middle" class="ui" font-size="12" fill="#89958F">A quiet timer stays visible without covering the conversation.</text>
                <rect x="370" y="374" width="150" height="5" rx="2.5" fill="#FFFFFF" fill-opacity="0.08"/>
                <rect x="370" y="374" width="92" height="5" rx="2.5" fill="#52CF61" fill-opacity="0.70"/>

                <g transform="translate(355 439)">
                    <circle cx="0" cy="0" r="15" fill="#252D2A"/><path d="M-4 -4 v6 a4 4 0 0 0 8 0 v-6 M-7 1 a7 7 0 0 0 14 0 M0 8 v4" fill="none" stroke="#CDD5D1" stroke-width="1.4" stroke-linecap="round"/>
                    <circle cx="43" cy="0" r="15" fill="#252D2A"/><rect x="37" y="-5" width="10" height="10" rx="2" fill="none" stroke="#CDD5D1" stroke-width="1.4"/><path d="M47 -2 l6 -3 v10 l-6 -3" fill="none" stroke="#CDD5D1" stroke-width="1.4"/>
                    <circle cx="86" cy="0" r="15" fill="#252D2A"/><path d="M80 -4 h12 v8 h-7 l-4 4 v-4 h-1z" fill="none" stroke="#CDD5D1" stroke-width="1.4"/>
                    <rect x="116" y="-15" width="66" height="30" rx="15" fill="#D94B4B"/><path d="M140 -1 q9 -6 18 0" fill="none" stroke="#FFFFFF" stroke-width="1.7" stroke-linecap="round"/>
                </g>
            </g>

            <g transform="translate(300 502)">
                <rect width="360" height="42" rx="15" fill="#EEF2F0" fill-opacity="0.24" stroke="#FFFFFF" stroke-opacity="0.14"/>
                <rect x="18" y="7" width="28" height="28" rx="7" fill="#70A8EF"/><path d="M24 22 h16 M32 14 v16" stroke="#FFFFFF" stroke-width="2" stroke-linecap="round"/>
                <rect x="56" y="7" width="28" height="28" rx="7" fill="#7E74DB"/><circle cx="70" cy="21" r="7" fill="none" stroke="#FFFFFF" stroke-width="2"/>
                <rect x="94" y="7" width="28" height="28" rx="7" fill="#4FC56A"/><path d="M101 24 l6 -7 5 5 4 -5" fill="none" stroke="#FFFFFF" stroke-width="2"/>
                <rect x="132" y="7" width="28" height="28" rx="7" fill="#171D1B" stroke="#52CF61" stroke-width="1.5"/><circle cx="146" cy="21" r="8" fill="none" stroke="#FFFFFF" stroke-width="1.7"/><path d="M146 21 v-5 M146 21 l4 2 M146 10 v-3" stroke="#FFFFFF" stroke-width="1.7" stroke-linecap="round"/>
                <rect x="170" y="7" width="28" height="28" rx="7" fill="#F4B44A"/>
                <rect x="208" y="7" width="28" height="28" rx="7" fill="#DD6D67"/>
                <rect x="246" y="7" width="28" height="28" rx="7" fill="#77858E"/>
                <rect x="284" y="7" width="28" height="28" rx="7" fill="#2F3432"/>
                <rect x="322" y="7" width="20" height="28" rx="6" fill="#232927"/><circle cx="332" cy="16" r="3" fill="#52CF61"/>
            </g>
        </g>
    </g>

    <g opacity="${titleFade.toFixed(3)}" filter="url(#textShadow)">
        <g transform="translate(80 79)">
            <rect width="126" height="30" rx="15" fill="#FFFFFF" fill-opacity="0.075" stroke="#FFFFFF" stroke-opacity="0.11"/>
            <circle cx="17" cy="15" r="4" fill="#52CF61"/>
            <text x="30" y="20" class="ui" font-size="11" font-weight="700" letter-spacing="1.5" fill="#DDE4E0">POMOTIMER</text>
        </g>
        <text x="80" y="180" class="ui" font-size="47" font-weight="650" letter-spacing="-1.5" fill="#F6F9F7">${escapeXML(title)}</text>
        <text x="82" y="220" class="ui" font-size="18" font-weight="400" fill="#AEB9B3">${escapeXML(subtitle)}</text>
        <g transform="translate(82 275)" opacity="${smooth(1.65, 2.25, time).toFixed(2)}">
            <circle cx="7" cy="7" r="7" fill="#52CF61" fill-opacity="0.18"/>
            <circle cx="7" cy="7" r="3" fill="#52CF61"/>
            <text x="25" y="12" class="ui" font-size="13" font-weight="550" fill="#D8E0DC">Persistent at the edge. Invisible when you need space.</text>
        </g>
    </g>

    <g transform="translate(${(panelX + panelWidth / 2).toFixed(2)} ${(panelY + panelHeight / 2).toFixed(2)}) scale(${lift.toFixed(4)}) translate(${(-panelWidth / 2).toFixed(2)} ${(-panelHeight / 2).toFixed(2)})" filter="url(#shadow)">
        <rect width="${panelWidth.toFixed(2)}" height="${panelHeight.toFixed(2)}" rx="${panelCornerRadius.toFixed(2)}" fill="url(#panel)" stroke="#FFFFFF" stroke-opacity="0.12"/>
        <rect x="1" y="1" width="${(panelWidth - 2).toFixed(2)}" height="${(panelHeight - 2).toFixed(2)}" rx="${Math.max(3, panelCornerRadius - 1).toFixed(2)}" fill="none" stroke="#FFFFFF" stroke-opacity="0.035"/>
        <g opacity="${tabOpacity.toFixed(2)}" transform="translate(${(panelWidth / 2).toFixed(2)} ${(panelHeight / 2).toFixed(2)}) scale(${(panelWidth / 58).toFixed(4)} ${(panelHeight / 152).toFixed(4)})">
            <circle cx="0" cy="-42" r="14" fill="none" stroke="#FFFFFF" stroke-width="2"/>
            <path d="M0 -60 v5 M-5 -59 h10 M9 -52 l5 -4" fill="none" stroke="#FFFFFF" stroke-width="2" stroke-linecap="round"/>
            <path d="M0 -42 v-8 M0 -42 l6 3" fill="none" stroke="#FFFFFF" stroke-width="2" stroke-linecap="round"/>
            <text transform="translate(3 25) rotate(90)" text-anchor="middle" class="display" font-size="17" font-weight="650" fill="#FFFFFF">${collapsedDisplay}</text>
        </g>

        <g opacity="${contentOpacity.toFixed(3)}" transform="scale(${(panelWidth / 300).toFixed(4)} ${(panelHeight / 500).toFixed(4)})" clip-path="url(#panelClip)">
            <path d="M18 28 l5 -5 M18 28 l5 5" fill="none" stroke="#8A928E" stroke-width="1.8" stroke-linecap="round"/>
            <text x="150" y="34" text-anchor="middle" class="ui" font-size="13" font-weight="650" letter-spacing="0.5" fill="#F3F6F4">STOPWATCH</text>
            <circle cx="273" cy="28" r="5" fill="#52CF61"/>
            <circle cx="273" cy="28" r="12" fill="#52CF61" opacity="${glow.toFixed(2)}"/>

            <text x="150" y="94" text-anchor="middle" class="display" font-size="37" font-weight="400" fill="#F7F9F8">${display}</text>
            <text x="150" y="118" text-anchor="middle" class="ui" font-size="13" fill="${running ? "#78E484" : "#9AA39E"}">${status}</text>

            <rect x="22" y="143" width="124" height="36" rx="8" fill="url(#button)" opacity="${startPressed ? 0.72 : 1}"/>
            <text x="84" y="166" text-anchor="middle" class="ui" font-size="13" font-weight="650" fill="#FFFFFF">${primaryLabel}</text>
            <rect x="158" y="143" width="120" height="36" rx="8" fill="#FFFFFF" fill-opacity="${resetPressed ? 0.16 : 0.09}"/>
            <text x="218" y="166" text-anchor="middle" class="ui" font-size="13" font-weight="600" fill="#ECEFED">Reset</text>

            <line x1="22" y1="198" x2="278" y2="198" stroke="#FFFFFF" stroke-opacity="0.10"/>
            <rect x="22" y="215" width="256" height="44" rx="9" fill="#000000" fill-opacity="0.14"/>
            <text x="85" y="240" text-anchor="middle" class="ui" font-size="13" font-weight="600" fill="#F3F6F4">Stopwatch</text>
            <text x="215" y="240" text-anchor="middle" class="ui" font-size="13" fill="#7C847F">Timer</text>
            <rect x="22" y="257" width="126" height="2.5" rx="1.25" fill="#52CF61"/>

            <g transform="translate(22 326)">
                ${row(0, "⚙", "Auto Hide", true)}
                ${row(39, "⌖", "Stay Active", false)}
                ${row(78, "▣", "Always on Top", false)}
            </g>
            <line x1="22" y1="429" x2="278" y2="429" stroke="#FFFFFF" stroke-opacity="0.10"/>
            <g transform="translate(22 461)">
                <text x="2" y="5" class="symbol" font-size="17" fill="#AAB2AE">↕</text>
                <text x="29" y="5" class="ui" font-size="13" fill="#E8ECEA">Hide countdown when idle</text>
                <rect x="223" y="-9" width="35" height="18" rx="9" fill="#6F7773"/>
                <circle cx="232" cy="0" r="7" fill="#F4F5F4"/>
            </g>
        </g>
    </g>

    <g transform="translate(${cursorX.toFixed(2)} ${cursorY.toFixed(2)})" opacity="${cursorOpacity.toFixed(3)}" filter="url(#textShadow)">
        ${clickPulse(time, 1.12)}
        ${clickPulse(time, 3.04)}
        ${clickPulse(time, 7.02)}
        ${clickPulse(time, 9.10)}
        <path d="M0 0 L0 27 L7 20 L13 33 L19 30 L13 18 L23 18 Z" fill="#FFFFFF" stroke="#111714" stroke-width="2" stroke-linejoin="round"/>
    </g>

    <g opacity="${autoHideLabelOpacity.toFixed(3)}" transform="translate(650 514)">
        <rect x="0" y="0" width="192" height="30" rx="15" fill="#0B110F" fill-opacity="0.90" stroke="#FFFFFF" stroke-opacity="0.12"/>
        <circle cx="17" cy="15" r="5" fill="#52CF61"/>
        <text x="31" y="20" class="ui" font-size="11" font-weight="650" fill="#E8EDEB">Auto Hide after inactivity</text>
    </g>

    <g opacity="${endCardOpacity.toFixed(3)}">
        <rect x="54" y="50" width="818" height="500" rx="17" fill="#07100D" fill-opacity="0.92"/>
        <text x="463" y="274" text-anchor="middle" class="ui" font-size="43" font-weight="680" letter-spacing="-1.2" fill="#F7FAF8">There when you need it.</text>
        <text x="463" y="326" text-anchor="middle" class="ui" font-size="43" font-weight="680" letter-spacing="-1.2" fill="#78E484">Gone when you don’t.</text>
        <text x="463" y="370" text-anchor="middle" class="ui" font-size="15" fill="#AAB6B0">Pomotimer keeps your meeting—and your focus—front and center.</text>
    </g>
</svg>`;
}

await rm(frameDirectory, { recursive: true, force: true });
await mkdir(frameDirectory, { recursive: true });

const frameCount = Math.round(duration * fps);
for (let frame = 0; frame < frameCount; frame += 1) {
    const time = frame / fps;
    const filename = `frame-${String(frame).padStart(4, "0")}.svg`;
    await writeFile(join(frameDirectory.pathname, filename), renderFrame(time));
}

console.log(JSON.stringify({ width, height, fps, duration, frameCount, frameDirectory: frameDirectory.pathname }));
