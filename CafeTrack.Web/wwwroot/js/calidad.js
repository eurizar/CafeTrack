// Formulario de catación. Tres ayudas para el catador:
//   1. El puntaje dice en vivo en qué categoría cae, y ajusta el resultado.
//   2. La altura se sugiere con la altitud de la parcela.
//   3. Las notas de la rueda de sabores marcan el perfil sin escribirlo.
(function () {
    'use strict';

    // Las ventanas de consulta las abre dialogo.js, que es general.

    // ------------------------------------------------- puntaje y resultado

    var puntaje = document.getElementById('puntaje');
    var resultado = document.getElementById('resultado');
    var ayudaPuntaje = document.getElementById('ayuda-puntaje');
    var ayudaResultado = document.getElementById('ayuda-resultado');

    /// Misma escala que muestra la ventana de ayuda.
    function categoria(valor) {
        if (valor >= 90) { return 'Excepcional: taza extraordinaria.'; }
        if (valor >= 85) { return 'Excelente: especialidad de alta gama.'; }
        if (valor >= 80) { return 'Muy bueno: entra como café de especialidad.'; }
        return 'Fuera de especialidad: no se puede aprobar para venta.';
    }

    function revisarPuntaje() {
        if (!puntaje || !ayudaPuntaje) { return; }

        var valor = parseFloat(puntaje.value);

        if (isNaN(valor)) {
            // Sin puntaje no hay resultado que proponer.
            ayudaPuntaje.textContent = 'Bajo 80 no se puede aprobar.';
            ayudaPuntaje.classList.remove('ayuda-alerta');
            if (resultado) { resultado.value = ''; }
            if (ayudaResultado) {
                ayudaResultado.textContent = 'Lo propone el puntaje.';
                ayudaResultado.classList.remove('ayuda-alerta');
            }
            return;
        }

        var bajo = valor < 80;
        ayudaPuntaje.textContent = valor.toFixed(2) + ' · ' + categoria(valor);
        ayudaPuntaje.classList.toggle('ayuda-alerta', bajo);

        // El resultado se acomoda solo: bajo 80 la base no deja aprobar, y
        // de 80 en adelante el lote va para venta. El catador puede cambiarlo.
        if (resultado) { resultado.value = bajo ? 'false' : 'true'; }

        if (ayudaResultado) {
            ayudaResultado.textContent = bajo
                ? 'Con menos de 80 puntos solo puede rechazarse.'
                : 'Lo propone el puntaje; puede cambiarlo.';
            ayudaResultado.classList.toggle('ayuda-alerta', bajo);
        }
    }

    if (puntaje) { puntaje.addEventListener('input', revisarPuntaje); }

    // -------------------------------------- altura sugerida por la altitud

    var lote = document.querySelector('select[name="Datos.IdLote"]');
    var altura = document.getElementById('altura');
    var ayudaAltura = document.getElementById('ayuda-altura-campo');

    /// Clasificación guatemalteca por altitud de siembra.
    function alturaPorAltitud(metros) {
        if (metros >= 1350) { return 'Estrictamente Altura'; }
        if (metros >= 1200) { return 'Altura'; }
        if (metros >= 900) { return 'Central'; }
        return 'Baja';
    }

    function sugerirAltura() {
        if (!lote || !altura) { return; }

        var op = lote.options[lote.selectedIndex];
        var metros = op ? parseInt(op.getAttribute('data-altitud'), 10) : NaN;

        if (!op || !op.value || isNaN(metros)) {
            // Sin lote la altura queda en blanco, como el resto del formulario.
            if (!op || !op.value) { altura.value = ''; }
            if (ayudaAltura) { ayudaAltura.textContent = 'La sugiere la altitud de la parcela.'; }
            return;
        }

        altura.value = alturaPorAltitud(metros);

        if (ayudaAltura) {
            ayudaAltura.textContent = 'Sugerida por los ' + metros +
                ' m de la parcela; puede cambiarla.';
        }
    }

    if (lote) { lote.addEventListener('change', sugerirAltura); }

    // ------------------------------------------------- notas sensoriales
    // El panel es una marca fija: no escribe en la nota libre. Lo marcado
    // viaja en un campo oculto y el servidor arma el perfil al guardar.

    var perfil = document.getElementById('perfil');
    var notas = document.getElementById('notas');
    var marcadas = document.getElementById('notas-marcadas');
    var vista = document.getElementById('vista-texto');

    /// Recorre el panel en orden y devuelve lo marcado, por familia.
    function recoger() {
        var familias = [];
        var porFamilia = {};

        notas.querySelectorAll('.nota[aria-pressed="true"]').forEach(function (boton) {
            var familia = boton.dataset.familia;

            if (!porFamilia[familia]) {
                porFamilia[familia] = [];
                familias.push(familia);
            }

            porFamilia[familia].push(boton.dataset.nota);
        });

        return { familias: familias, notas: porFamilia };
    }

    /// Deja el campo oculto y la vista previa al dia.
    function actualizarNotas() {
        if (!notas || !marcadas) { return; }

        var elegido = recoger();
        var fichas = [];
        var partes = [];

        elegido.familias.forEach(function (familia) {
            elegido.notas[familia].forEach(function (nota) {
                fichas.push(familia + '>' + nota);
            });

            partes.push(familia + ': ' + elegido.notas[familia].join(', '));
        });

        marcadas.value = fichas.join('|');

        if (!vista) { return; }

        var libre = perfil ? perfil.value.trim() : '';
        if (libre !== '') { partes.push('Nota: ' + libre); }

        vista.textContent = partes.length === 0
            ? 'Marque las notas que encontró en la taza.'
            : partes.join(' · ');
    }

    if (notas) {
        notas.addEventListener('click', function (evento) {
            var boton = evento.target.closest('.nota');
            if (!boton) { return; }

            var puesta = boton.getAttribute('aria-pressed') === 'true';
            boton.setAttribute('aria-pressed', puesta ? 'false' : 'true');
            boton.classList.toggle('nota-puesta', !puesta);
            actualizarNotas();
        });
    }

    if (perfil) { perfil.addEventListener('input', actualizarNotas); }

    /// Si la pagina vuelve con un error, se restauran las marcas.
    function restaurarNotas() {
        if (!notas || !marcadas) { return; }

        var guardadas = (marcadas.defaultValue || '').split('|');

        notas.querySelectorAll('.nota').forEach(function (boton) {
            var ficha = boton.dataset.familia + '>' + boton.dataset.nota;
            var puesta = guardadas.indexOf(ficha) !== -1;
            boton.setAttribute('aria-pressed', puesta ? 'true' : 'false');
            boton.classList.toggle('nota-puesta', puesta);
        });

        actualizarNotas();
    }

    // Al recargar, el navegador reescribe lo que el usuario había tecleado.
    // Aquí se vuelve a lo que mandó el servidor: en blanco al entrar y
    // después de registrar, y con los datos del intento si hubo error.
    function arrancarLimpio() {
        var form = document.querySelector('form.formulario');
        if (!form) { return; }

        form.querySelectorAll('input, textarea').forEach(function (campo) {
            if (campo.type === 'hidden' || campo.readOnly) { return; }
            campo.value = campo.defaultValue;
        });

        form.querySelectorAll('select').forEach(function (lista) {
            var i = 0;
            for (; i < lista.options.length; i++) {
                if (lista.options[i].defaultSelected) { lista.selectedIndex = i; return; }
            }
            lista.selectedIndex = 0;
        });
    }

    arrancarLimpio();
    sugerirAltura();
    revisarPuntaje();
    restaurarNotas();
})();
