// Formulario de beneficiado. Arranca en blanco: al elegir el lote se
// llenan solos la etapa que toca, el peso de entrada y la hora de inicio.
// Al volver a "Seleccione un lote" todo se limpia otra vez.
// La validacion de verdad la hace sp_registrar_proceso en la base.
(function () {
    'use strict';

    var lote = document.getElementById('lote');
    var etapa = document.getElementById('etapa');
    var etapaTexto = document.getElementById('etapa-texto');
    var entrada = document.getElementById('entrada');
    var salida = document.getElementById('salida');
    var inicio = document.getElementById('inicio');
    var cierre = document.querySelector('input[name="Datos.FechaFin"]');
    var ayudaEtapa = document.getElementById('ayuda-etapa');
    var ayudaMerma = document.getElementById('ayuda-merma');
    if (!lote || !etapa) { return; }

    var baseMerma = ayudaMerma ? ayudaMerma.textContent : '';

    // Se registra lo que ya ocurrio: el navegador no deja elegir una fecha
    // futura, y la base lo vuelve a verificar al guardar.
    // En modo demostracion no se pone tope: la base tampoco lo exige.
    var permiteFuturas = (function () {
        var form = lote.closest('form');
        return form && form.dataset.futuras === '1';
    })();

    function topeAhora() {
        if (permiteFuturas) { return; }

        var tope = ahora();
        if (inicio) { inicio.max = tope; }
        if (cierre) { cierre.max = tope; }
    }

    /// El navegador avisa con un texto generico ("el valor debe ser igual o
    /// anterior a..."). Aqui se reemplaza por uno que explica el porque.
    function explicarTope(campo, texto) {
        if (!campo) { return; }

        campo.addEventListener('invalid', function () {
            if (campo.validity.rangeOverflow) {
                campo.setCustomValidity(texto + ' Ahora son las ' + reloj() + '.');
            }
        });

        // Al corregir el valor se limpia el aviso.
        campo.addEventListener('input', function () {
            campo.setCustomValidity('');
        });
    }

    /// Hora actual en formato legible: 12:02.
    function reloj() {
        var d = new Date();
        return ('0' + d.getHours()).slice(-2) + ':' + ('0' + d.getMinutes()).slice(-2);
    }

    /// Devuelve la fecha y hora de ahora en el formato del campo.
    function ahora() {
        var d = new Date();
        d.setMinutes(d.getMinutes() - d.getTimezoneOffset());
        return d.toISOString().slice(0, 16);
    }

    function limpiar() {
        etapa.value = '';
        if (etapaTexto) { etapaTexto.value = ''; }
        if (entrada) { entrada.value = ''; entrada.removeAttribute('max'); }
        if (salida) { salida.value = ''; }
        if (inicio) { inicio.value = ''; inicio.readOnly = false; }
        if (cierre) { cierre.value = ''; }

        if (ayudaEtapa) {
            ayudaEtapa.textContent = 'Elija el lote y la etapa aparece sola.';
            ayudaEtapa.classList.remove('ayuda-alerta');
        }

        if (ayudaMerma) {
            ayudaMerma.textContent = baseMerma;
            ayudaMerma.classList.remove('ayuda-alerta');
        }
    }

    function sincronizar() {
        var op = lote.options[lote.selectedIndex];

        if (!op || !op.value) {
            limpiar();
            return;
        }

        // La etapa no se elige: viene calculada con lo que ya se registro.
        etapa.value = op.getAttribute('data-etapa');

        if (etapaTexto) {
            var nombre = op.getAttribute('data-etapa-nombre') || '';
            var rango = op.getAttribute('data-rango');
            etapaTexto.value = rango ? nombre + '  (' + rango + ')' : nombre;
        }

        var peso = parseFloat(op.getAttribute('data-peso'));
        if (!isNaN(peso) && entrada) {
            entrada.value = peso.toFixed(2);
            entrada.max = peso;
        }

        var abierta = op.getAttribute('data-abierta') === '1';
        var desde = op.getAttribute('data-inicio');

        if (inicio) {
            // Si la etapa ya esta abierta se respeta su hora de inicio.
            inicio.value = abierta && desde ? desde : ahora();
            inicio.readOnly = abierta;
        }

        if (ayudaEtapa) {
            ayudaEtapa.textContent = abierta
                ? 'Ya está abierta: al guardar se cierra con la fecha y el peso de salida.'
                : 'La calcula la base; no se puede saltar a otra.';
            ayudaEtapa.classList.toggle('ayuda-alerta', abierta);
        }

        calcular();
    }

    function calcular() {
        if (!ayudaMerma || !entrada || !salida) { return; }

        var e = parseFloat(entrada.value);
        var s = parseFloat(salida.value);

        if (isNaN(e) || isNaN(s)) {
            ayudaMerma.textContent = baseMerma;
            ayudaMerma.classList.remove('ayuda-alerta');
            return;
        }

        if (s > e) {
            ayudaMerma.textContent = 'De una etapa no puede salir más de lo que entró.';
            ayudaMerma.classList.add('ayuda-alerta');
            return;
        }

        var merma = e - s;
        var pct = e > 0 ? (merma / e) * 100 : 0;
        ayudaMerma.textContent = 'Merma de la etapa: ' + merma.toFixed(2) +
            ' qq (' + pct.toFixed(2) + ' %).';
        ayudaMerma.classList.toggle('ayuda-alerta', pct > 15);
    }

    lote.addEventListener('change', sincronizar);
    if (entrada) { entrada.addEventListener('input', calcular); }
    if (salida) { salida.addEventListener('input', calcular); }

    // El tope se refresca cada minuto por si la pantalla queda abierta.
    topeAhora();
    window.setInterval(topeAhora, 60000);

    explicarTope(inicio, 'Se registra lo que ya ocurrió: la etapa no puede empezar en el futuro.');
    explicarTope(cierre, 'La etapa no puede cerrar en el futuro. Si todavía no termina, deje este campo vacío.');

    // Al cargar la pagina el lote viene sin elegir: todo limpio.
    sincronizar();
})();
