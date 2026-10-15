// Boton para mostrar u ocultar la contrasena. Sin librerias.
// Si el navegador no ejecuta JavaScript el boton no aparece y el campo
// sigue funcionando como un campo de contrasena normal.
(function () {
    'use strict';

    var campo = document.getElementById('clave');
    var boton = document.getElementById('ojo-clave');
    if (!campo || !boton) { return; }

    boton.hidden = false;

    boton.addEventListener('click', function () {
        var visible = campo.type === 'text';
        campo.type = visible ? 'password' : 'text';
        boton.setAttribute('aria-pressed', visible ? 'false' : 'true');
        boton.title = visible ? 'Mostrar contraseña' : 'Ocultar contraseña';

        var texto = boton.querySelector('.oculto-visual');
        if (texto) { texto.textContent = boton.title; }

        campo.focus();
    });
})();
