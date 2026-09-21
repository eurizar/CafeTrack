// Contrae o expande la barra lateral y recuerda la preferencia entre paginas.
// JavaScript propio, sin librerias: el proyecto no usa frameworks de front-end.
(function () {
    'use strict';

    var raiz = document.documentElement;
    var boton = document.getElementById('barra-boton');
    if (!boton) { return; }

    function aplicar(compacta) {
        raiz.classList.toggle('barra-compacta', compacta);
        boton.setAttribute('aria-expanded', compacta ? 'false' : 'true');
        boton.title = compacta ? 'Expandir la barra' : 'Contraer la barra';
        var texto = boton.querySelector('.oculto-visual');
        if (texto) { texto.textContent = boton.title; }
    }

    // Sincroniza el boton con el estado que restauro el script del <head>.
    aplicar(raiz.classList.contains('barra-compacta'));

    boton.addEventListener('click', function () {
        var compacta = !raiz.classList.contains('barra-compacta');
        aplicar(compacta);
        try {
            localStorage.setItem('cafetrack-barra', compacta ? 'compacta' : 'amplia');
        } catch (e) { /* sin almacenamiento: el estado dura solo esta pagina */ }
    });
})();
