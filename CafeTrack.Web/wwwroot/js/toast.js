// Avisos de la esquina: se esconden solos a los pocos segundos.
// El reloj se detiene mientras el puntero esta encima, para que a nadie
// se le escape el mensaje por estar leyendo.
(function () {
    'use strict';

    document.querySelectorAll('.toast').forEach(function (toast) {
        var duracion = parseInt(toast.dataset.duracion, 10) || 7000;
        var barra = toast.querySelector('.toast-barra');
        var reloj = null;
        var cerrado = false;

        if (barra) {
            barra.style.animationDuration = duracion + 'ms';
            toast.classList.add('con-barra');
        }

        function cerrar() {
            if (cerrado) { return; }
            cerrado = true;
            toast.classList.add('toast-sale');

            // Se quita del DOM cuando termina la animacion de salida.
            toast.addEventListener('animationend', function () {
                toast.remove();
            }, { once: true });
        }

        function arrancar() {
            reloj = window.setTimeout(cerrar, duracion);
            if (barra) { barra.style.animationPlayState = 'running'; }
        }

        function pausar() {
            window.clearTimeout(reloj);
            if (barra) { barra.style.animationPlayState = 'paused'; }
        }

        toast.addEventListener('mouseenter', pausar);
        toast.addEventListener('focusin', pausar);
        toast.addEventListener('mouseleave', arrancar);
        toast.addEventListener('focusout', arrancar);

        var boton = toast.querySelector('.toast-cerrar');
        if (boton) { boton.addEventListener('click', cerrar); }

        arrancar();
    });
})();
