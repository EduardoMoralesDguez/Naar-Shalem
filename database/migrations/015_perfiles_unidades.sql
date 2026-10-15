-- Perfil de unidad: solo resumen agregado de asistencia, sin registros individuales.
BEGIN;
DO $$ BEGIN
 IF NOT EXISTS(SELECT 1 FROM privado.migraciones WHERE version='014_organizacion') THEN RAISE EXCEPTION 'Ejecuta primero 014_organizacion.sql'; END IF;
END $$;
CREATE OR REPLACE FUNCTION public.organizacion_panel(p_ciclo UUID DEFAULT NULL) RETURNS JSONB LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' AS $$
DECLARE ciclo UUID; actor public.usuarios%ROWTYPE; BEGIN
 SELECT * INTO actor FROM public.usuarios WHERE id_usuario=privado.mi_id();
 IF actor.id_usuario IS NULL THEN RAISE EXCEPTION 'Inicia sesión.' USING ERRCODE='42501'; END IF;
 ciclo:=coalesce(p_ciclo,(SELECT id_ciclo FROM public.ciclos WHERE es_activo));
 IF NOT EXISTS(SELECT 1 FROM public.ciclos WHERE id_ciclo=ciclo AND (es_activo OR actor.rol='directiva')) THEN RAISE EXCEPTION 'Ciclo no disponible.' USING ERRCODE='42501'; END IF;
 RETURN jsonb_build_object('id_ciclo',ciclo,'vigente',EXISTS(SELECT 1 FROM public.ciclos WHERE id_ciclo=ciclo AND es_activo),'rol',actor.rol,
 'ciclos',(SELECT jsonb_agg(to_jsonb(c) ORDER BY anio DESC) FROM public.ciclos c WHERE es_activo OR actor.rol='directiva'),
 'unidades',coalesce((SELECT jsonb_agg(to_jsonb(u)||jsonb_build_object('editable',privado.editar_unidad(u.id_unidad),
 'asistencia',(SELECT jsonb_build_object('total',count(*),'asistencias',count(*) FILTER(WHERE a.estado='asistencia'),'justificados',count(*) FILTER(WHERE a.estado='justificado'),'faltas',count(*) FILTER(WHERE a.estado='falta'),'porcentaje',CASE WHEN count(*)>0 THEN round(100.0*count(*) FILTER(WHERE a.estado IN ('asistencia','justificado'))/count(*)) ELSE NULL END)
 FROM privado.convocados_asistencia a JOIN privado.reuniones r ON r.id=a.reunion
 WHERE a.id_unidad=u.id_unidad AND r.id_ciclo=ciclo AND r.tipo='regular' AND r.estado='cerrada' AND NOT r.eliminado)) ORDER BY nombre) FROM public.unidades u WHERE id_ciclo=ciclo),'[]'::jsonb),
 'clases',coalesce((SELECT jsonb_agg(to_jsonb(c)||jsonb_build_object('nombre',CASE WHEN EXISTS(SELECT 1 FROM public.ciclos WHERE id_ciclo=ciclo AND es_activo) THEN c.nombre ELSE coalesce((SELECT i.nombre_clase FROM privado.inscripciones i WHERE i.id_ciclo=ciclo AND i.id_clase=c.id_clase LIMIT 1),c.nombre) END) ORDER BY nombre) FROM public.clases c),'[]'::jsonb),
 'integrantes',coalesce((SELECT jsonb_agg(jsonb_build_object('id_usuario',i.id_usuario,'nombre',u.nombres||' '||u.apellido,'id_unidad',i.id_unidad,'id_clase',i.id_clase,'rol',i.rol,'activo',i.activo,'version',u.version_perfil,'unidad',i.nombre_unidad,'clase',i.nombre_clase) ORDER BY u.apellido,u.nombres)
 FROM privado.inscripciones i JOIN public.usuarios u USING(id_usuario) WHERE i.id_ciclo=ciclo AND (i.activo OR actor.rol='directiva')),'[]'::jsonb));
END $$;
REVOKE ALL ON FUNCTION public.organizacion_panel(uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.organizacion_panel(uuid) TO authenticated;
INSERT INTO privado.migraciones(version) VALUES('015_perfiles_unidades') ON CONFLICT DO NOTHING;
NOTIFY pgrst,'reload schema';
COMMIT;
