(self.webpackChunk_N_E=self.webpackChunk_N_E||[]).push([[871],{9152:function(e,t,r){Promise.resolve().then(r.bind(r,8693))},8693:function(e,t,r){"use strict";r.r(t),r.d(t,{default:function(){return a}});var n=r(7437),o=r(2265),i=r(257);function a(){let[e,t]=(0,o.useState)(null),[r,a]=(0,o.useState)(""),[c,l]=(0,o.useState)(""),s=i.env.NEXT_PUBLIC_API_URL||"http://localhost:9000";async function u(t){if(t.preventDefault(),!e){l("No PDF file selected.");return}try{let t=new FormData;t.append("file",e),t.append("doc_category",r);let n=await fetch("".concat(s,"/pdf/upload_pdf"),{method:"POST",body:t}),o=await n.json();n.ok?l("Upload success: ".concat(JSON.stringify(o))):l("Error: ".concat(o.detail||o.error||JSON.stringify(o)))}catch(e){l("[Error: ".concat(String(e),"]"))}}return(0,n.jsxs)("main",{className:"max-w-3xl mx-auto p-6 space-y-6",children:[(0,n.jsx)("h1",{className:"text-2xl font-bold text-orange-400",children:"PDF Upload"}),(0,n.jsxs)("form",{onSubmit:u,className:"border border-gray-700 p-4 bg-black/50 rounded space-y-4",children:[(0,n.jsxs)("div",{children:[(0,n.jsx)("label",{className:"block text-sm text-gray-300 mb-1",children:"Select PDF:"}),(0,n.jsx)("input",{type:"file",accept:"application/pdf",onChange:e=>{e.target.files&&e.target.files.length>0?t(e.target.files[0]):t(null)},className:"text-sm file:mr-4 file:py-1 file:px-2 file:rounded file:border-0  file:bg-[#00ff66] file:text-black hover:file:bg-[#00c653]"})]}),(0,n.jsxs)("div",{children:[(0,n.jsx)("label",{className:"block text-sm text-gray-300 mb-1",children:"Document Category (optional):"}),(0,n.jsx)("input",{type:"text",className:"bg-gray-800 border border-gray-600 text-gray-100 px-3 py-2 rounded w-full",placeholder:"e.g. finance",value:r,onChange:e=>a(e.target.value)})]}),(0,n.jsx)("button",{className:"bg-[#00ff66] text-black font-bold px-4 py-2 rounded hover:bg-[#00c653]",children:"Upload"}),c&&(0,n.jsx)("p",{className:"mt-2 text-xs text-yellow-400 whitespace-pre-wrap",children:c})]}),(0,n.jsxs)("p",{className:"text-sm text-gray-400",children:["Return to"," ",(0,n.jsx)("a",{href:"/",className:"underline text-blue-400",children:"Home synergy"}),"."]})]})}},257:function(e,t,r){"use strict";var n,o;e.exports=(null==(n=r.g.process)?void 0:n.env)&&"object"==typeof(null==(o=r.g.process)?void 0:o.env)?r.g.process:r(4227)},4227:function(e){!function(){var t={229:function(e){var t,r,n,o=e.exports={};function i(){throw Error("setTimeout has not been defined")}function a(){throw Error("clearTimeout has not been defined")}function c(e){if(t===setTimeout)return setTimeout(e,0);if((t===i||!t)&&setTimeout)return t=setTimeout,setTimeout(e,0);try{return t(e,0)}catch(r){try{return t.call(null,e,0)}catch(r){return t.call(this,e,0)}}}!function(){try{t="function"==typeof setTimeout?setTimeout:i}catch(e){t=i}try{r="function"==typeof clearTimeout?clearTimeout:a}catch(e){r=a}}();var l=[],s=!1,u=-1;function f(){s&&n&&(s=!1,n.length?l=n.concat(l):u=-1,l.length&&p())}function p(){if(!s){var e=c(f);s=!0;for(var t=l.length;t;){for(n=l,l=[];++u<t;)n&&n[u].run();u=-1,t=l.length}n=null,s=!1,function(e){if(r===clearTimeout)return clearTimeout(e);if((r===a||!r)&&clearTimeout)return r=clearTimeout,clearTimeout(e);try{r(e)}catch(t){try{return r.call(null,e)}catch(t){return r.call(this,e)}}}(e)}}function d(e,t){this.fun=e,this.array=t}function h(){}o.nextTick=function(e){var t=Array(arguments.length-1);if(arguments.length>1)for(var r=1;r<arguments.length;r++)t[r-1]=arguments[r];l.push(new d(e,t)),1!==l.length||s||c(p)},d.prototype.run=function(){this.fun.apply(null,this.array)},o.title="browser",o.browser=!0,o.env={},o.argv=[],o.version="",o.versions={},o.on=h,o.addListener=h,o.once=h,o.off=h,o.removeListener=h,o.removeAllListeners=h,o.emit=h,o.prependListener=h,o.prependOnceListener=h,o.listeners=function(e){return[]},o.binding=function(e){throw Error("process.binding is not supported")},o.cwd=function(){return"/"},o.chdir=function(e){throw Error("process.chdir is not supported")},o.umask=function(){return 0}}},r={};function n(e){var o=r[e];if(void 0!==o)return o.exports;var i=r[e]={exports:{}},a=!0;try{t[e](i,i.exports,n),a=!1}finally{a&&delete r[e]}return i.exports}n.ab="//";var o=n(229);e.exports=o}()}},function(e){e.O(0,[971,117,744],function(){return e(e.s=9152)}),_N_E=e.O()}]);